--[[
-------------------------------------------------------------------------------
-- @author Colby Klein
-- @author Landon Manning
-- @copyright 2016
-- @license MIT/X11
-------------------------------------------------------------------------------
                  .'@@@@@@@@@@@@@@#:
              ,@@@@#;            .'@@@@+
           ,@@@'                      .@@@#
         +@@+            ....            .@@@
       ;@@;         '@@@@@@@@@@@@.          @@@
      @@#         @@@@@@@@++@@@@@@@;         `@@;
    .@@`         @@@@@#        #@@@@@          @@@
   `@@          @@@@@` Cirno's  `@@@@#          +@@
   @@          `@@@@@  Perfect   @@@@@           @@+
  @@+          ;@@@@+ Collision  +@@@@+           @@
  @@           `@@@@@  Library   @@@@@@           #@'
 `@@            @@@@@@          @@@@@@@           `@@
 :@@             #@@@@@@.    .@@@@@@@@@            @@
 .@@               #@@@@@@@@@@@@;;@@@@@            @@
  @@                  .;+@@#'.   ;@@@@@           :@@
  @@`                            +@@@@+           @@.
  ,@@                            @@@@@           .@@
   @@#          ;;;;;.          `@@@@@           @@
    @@+         .@@@@@          @@@@@           @@`
     #@@         '@@@@@#`    ;@@@@@@          ;@@
      .@@'         @@@@@@@@@@@@@@@           @@#
        +@@'          '@@@@@@@;            @@@
          '@@@`                         '@@@
             #@@@;                  .@@@@:
                :@@@@@@@++;;;+#@@@@@@+`
                      .;'+++++;.
--]]
local modules = (...) and (...):gsub('%.init$', '') .. ".modules." or ""

local cpcl = {
	_LICENSE = "CPCL is distributed under the terms of the MIT license. See LICENSE.md.",
	_URL = "https://github.com/excessive/cpcl",
	_VERSION = "0.0.9",
	_DESCRIPTION = "Cirno's Perfect Collision Library: Now you, too, can slam things together."
}

local files = {
	"collision"
}

for _, file in ipairs(files) do
	cpcl[file] = require(modules .. file)
end

return cpcl
