# Cirno's Perfect Collision Library

Smash a thing into another thing!

Intended to be used with LuaJIT and LÖVE.

## Dependencies

* [Cirno's Perfect Math Library][cpml]

## Documentation

Online documentation can be found [here][docs] or you can generate them yourself
using `ldoc -c doc/config.ld -o index .`

## Credits

Credit to Kasper Fauerby for writing [this][peroxide] original white paper
outlining the collision algorithm.

Credit to the Nikolaus Gebhardt for using the aforementioned paper to create the
collision system in the [Irrlicht Engine][irrlicht] where we were able to find
several bug fixes and optimizations to our own implementation.

[cpml]: https://github.com/excessive/cpml
[docs]: http://excessive.github.io/cpcl
[peroxide]: http://www.peroxide.dk/papers/collision/collision.pdf
[irrlicht]: https://sourceforge.net/p/irrlicht/code/HEAD/tree/trunk/source/Irrlicht/CSceneCollisionManager.cpp

