local modules     = (...):gsub('%.[^%.]+$', '') .. "."
local cpml        = require "cpml"
local vec3        = cpml.vec3
local mesh        = cpml.mesh
local utils       = cpml.utils
local intersect   = cpml.intersect
local FLT_EPSILON = cpml.constants.FLT_EPSILON
local sqrt        = math.sqrt
local collision   = {}

-- a is a number
-- b is a number
-- c is a number
-- maxR is a number
-- returns root or false.
local function get_lowest_root(a, b, c, maxR)
	-- Check if a solution exists
	local determinant = b * b - 4 * a * c

	-- If determinant is negative it means no solutions.
	if determinant < 0 or a == 0 then return false end

	-- calculate the two roots: (if determinant == 0 then
	-- x1==x2 but let’s disregard that slight optimization)
	local sqrtD = sqrt(determinant)
	local invDA = 1 / (2 * a)
	local r1 = (-b - sqrtD) * invDA
	local r2 = (-b + sqrtD) * invDA

	-- Swap such that r1 <= r2
	if r1 > r2 then
		r1, r2 = r2, r1
	end

	-- Get lowest root:
	if r1 > 0 and r1 < maxR then
		return r1
	end

	-- It is possible that we want x2 - this can happen
	-- if x1 < 0
	if r2 > 0 and r2 < maxR then
		return r2
	end

	-- No (valid) solutions
	return false
end

function collision.packet_from_entity(entity, z_offset)
	local packet = {}

	-- Information about the move being requested: (in world space)
	packet.position = entity.position:clone()
	packet.z_offset = z_offset or 0
	packet.position.z = packet.position.z + packet.z_offset
	packet.velocity = entity.velocity:clone()

	-- Information about the move being requested: (in ellipsoid space)
	packet.e_radius              = entity.radius
	packet.e_velocity            = vec3():div(packet.velocity, packet.e_radius)
	packet.e_normalized_velocity = vec3():normalize(packet.e_velocity)
	packet.e_base_point          = vec3()

	-- Hit information
	packet.found_collision    = false
	packet.nearest_distance   = math.huge
	packet.intersection_point = vec3()
	packet.slope              = vec3()

	return packet
end

-- Assumes: triangle is given in ellipsoid space:
function collision.check_triangle(packet, triangle, cull_back_face)
	cull_back_face = cull_back_face and true or false

	-- Make the plane containing this triangle.
	local plane = mesh.plane_from_triangle(triangle)

	-- Is triangle front-facing to the velocity vector?
	-- We only check front-facing triangles
	-- (your choice of course)
	if cull_back_face and mesh.is_front_facing(plane, packet.e_normalized_velocity) then
		return
	end

	-- Get interval of plane intersection:
	local t0, t1
	local embedded_in_plane = false

	-- Calculate the signed distance from sphere
	-- position to triangle plane
	local signed_dist = mesh.signed_distance(packet.e_base_point, plane)

	-- cache this as we’re going to use it a few times below:
	local nv_dot = plane.normal:dot(packet.e_velocity)

	-- if sphere is travelling parrallel to the plane:
	if math.abs(nv_dot) < FLT_EPSILON then
		if math.abs(signed_dist) >= 1 then
			-- Sphere is not embedded in plane.
			-- No collision possible:
			return
		else
			-- sphere is embedded in plane.
			-- It intersects in the whole range [0..1]
			embedded_in_plane = true
			t0 = 0
		end
	else
		-- N dot D is not 0. Calculate intersection interval:
		local nvi = 1/nv_dot
		t0 = (-1 - signed_dist) * nvi
		t1 = ( 1 - signed_dist) * nvi

		-- Swap so t0 < t1
		if t0 > t1 then
			t0, t1 = t1, t0
		end

		-- Check that at least one result is within range:
		if t0 > 1 or t1 < 0 then
			--print(signed_dist, t0, t1)
			-- Both t values are outside values [0,1]
			-- No collision possible:
			return
		end

		-- Clamp to [0,1]
		t0 = utils.clamp(t0, 0, 1)
	end

	-- OK, at this point we have two time values t0 and t1
	-- between which the swept sphere intersects with the
	-- triangle plane. If any collision is to occur it must
	-- happen within this interval.
	local collision_point
	local found_collison = false
	local t = 1

	-- First we check for the easy case - collision inside
	-- the triangle. If this happens it must be at time t0
	-- as this is when the sphere rests on the front side
	-- of the triangle plane. Note, this can only happen if
	-- the sphere is not embedded in the triangle plane.
	if not embedded_in_plane then
		local plane_intersection_point = (packet.e_base_point - plane.normal) + packet.e_velocity * t0

		if intersect.point_triangle(plane_intersection_point, triangle, false) then
			t = t0
			collision_point = plane_intersection_point
			found_collison = true
		end
	end

	-- if we haven’t found a collision yet we’ll have to
	-- sweep sphere against vertices of the triangle.
	if not found_collison then
		local base          = packet.e_base_point
		local velocity      = packet.e_velocity
		local velocity_len2 = velocity:len2()

		-- For each vertex a quadratic equation has to
		-- be solved. We parameterize this equation as
		-- a*t^2 + b*t + c = 0 and below we calculate the
		-- parameters a, b, and c for each test.
		-- Check against points:
		for _, vertex in ipairs(triangle) do
			local a = velocity_len2
			local b = velocity:dot(base - vertex) * 2
			local c = (vertex - base):len2() - 1

			local found = get_lowest_root(a, b, c, t)
			if found then
				t = found
				collision_point = vertex
				found_collison  = true
				break
			end
		end

		-- if we haven’t found a collision yet we’ll have to
		-- sweep sphere against edges of the triangle.
		local hax = { 2, 3, 1 }

		-- For each edge a quadratic equation has to
		-- be solved. We parameterize this equation as
		-- a*t^2 + b*t + c = 0 and below we calculate the
		-- parameters a, b, and c for each test.
		-- Check against points:
		for v1, v2 in ipairs(hax) do
			local edge             = triangle[v1] - triangle[v2]
			local base_to_vertex   = triangle[v2] - base
			local edge_len2        = edge:len2()
			local ev_dot           = edge:dot(velocity)
			local eb_dot_to_vertex = edge:dot(base_to_vertex)

			-- Calculate parameters for equation
			local a = edge_len2 * -velocity_len2 + ev_dot * ev_dot
			local b = edge_len2 * (2 * velocity:dot(base_to_vertex)) - 2 * ev_dot * eb_dot_to_vertex
			local c = edge_len2 * (1 - base_to_vertex:len2()) + eb_dot_to_vertex * eb_dot_to_vertex

			-- Does the swept sphere collide against infinite edge?
			local found = get_lowest_root(a, b, c, t)
			if found then
				-- Check if intersection is within line segment:
				local f = (ev_dot * found - eb_dot_to_vertex) / edge_len2

				if f >= 0 and f <= 1 then
					-- intersection took place within segment.
					t = found
					collision_point = triangle[v2] +  edge * f
					found_collison  = true
					break
				end
			end
		end
	end

	-- Set result:
	if found_collison then
		-- distance to collision: ’t’ is time of collision
		local dist_to_collision = t * packet.velocity:len()

		-- Does this triangle qualify for the closest hit?
		-- it does if it’s the first hit or the closest
		if not packet.found_collision or dist_to_collision < packet.nearest_distance then
			-- Collision information nessesary for sliding
			packet.nearest_distance   = dist_to_collision
			packet.intersection_point = collision_point
			packet.found_collision    = true
		end
	end
end

function collision.collide_with_world(packet, position, velocity, slope_threshold, depth)
	depth = depth or 1
	local very_close_distance = 0.00005 -- 5mm / 100

	-- do we need to worry?
	if depth > 5 then
		return position
	end

	-- Ok, we need to worry:
	packet.e_velocity            = velocity
	packet.e_normalized_velocity = vec3():normalize(velocity)
	packet.e_base_point          = position
	packet.found_collision       = false
	packet.nearest_distance      = math.huge

	-- Check for collision (calls the collision routines)
	-- Application specific!!
	packet:check_collision()

	-- If no collision we just move along the velocity
	if not packet.found_collision then
		return position + velocity
	end

	-- *** Collision occured ***
	-- The original destination point
	local destination_point = position + velocity
	local new_base_point    = position

	-- only update if we are not already very close
	-- and if so we only move very close to intersection..not
	-- to the exact spot.
	if packet.nearest_distance >= very_close_distance then
		local v = velocity:clone()
		v:trim(v, packet.nearest_distance - very_close_distance)
		new_base_point = packet.e_base_point + v
		-- Adjust polygon intersection point (so sliding
		-- plane will be unaffected by the fact that we
		-- move slightly less than collision tells us)
		v:normalize(v)
		packet.intersection_point = packet.intersection_point - v * very_close_distance
	end

	if packet.intersection_point.z > position.z then
		destination_point.z         = position.z
		packet.intersection_point.z = position.z
	end

	-- Determine the sliding plane
	local slide_plane = {
		origin = packet.intersection_point,
		normal = vec3():normalize(new_base_point - packet.intersection_point)
	}

	-- Again, sorry about formatting.. but look carefully ;)
	local slide_factor = mesh.signed_distance(destination_point, slide_plane)
	local fire = require "fire"
	if slide_plane.normal:dot(vec3.unit_z) > slope_threshold then
		return new_base_point
	end
	local new_destination_point = destination_point - slide_plane.normal * slide_factor

	-- Generate the slide vector, which will become our new
	-- velocity vector for the next iteration
	local new_velocity = new_destination_point - packet.intersection_point

	if slide_plane.normal:dot(-vec3.unit_z) > -1 then
		packet.slope = slide_plane.normal
	end

	-- Recurse:
	-- dont recurse if the new velocity is very small
	if new_velocity:len() < very_close_distance then
		return new_base_point
	end

	return collision.collide_with_world(packet, new_base_point, new_velocity, slope_threshold, depth + 1)
end

-- packet is a player table
-- gravity is a vec3 or false
function collision.collide_and_slide(packet, gravity, slope_threshold)
	-- calculate position and velocity in eSpace
	local e_radius   = packet.e_radius
	local e_position = packet.position / packet.e_radius
	local e_velocity = packet.velocity / packet.e_radius

	packet.slope = false

	-- Iterate until we have our final position.
	local final_position = collision.collide_with_world(packet, e_position, e_velocity, slope_threshold)

	-- Add gravity pull:
	-- Set the new position (convert back from ellipsoid space to world space)
	packet.position = final_position * e_radius
	packet.position.z = packet.position.z + packet.z_offset

	if gravity then
		packet.velocity = gravity
		e_velocity      = gravity / e_radius

		-- Iterate until we have our final position.
		final_position = collision.collide_with_world(packet, final_position, e_velocity, slope_threshold)
	end

	-- Convert final result back to world space:
	packet.position = final_position * e_radius
end

return collision
