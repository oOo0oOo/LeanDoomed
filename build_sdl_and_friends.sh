cd vendor/SDL
cmake -S . -B build
cmake --build build
cd ../SDL_image
cmake -S . -B build -DSDL3_DIR=../SDL/build
cmake --build build