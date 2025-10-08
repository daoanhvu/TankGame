# Build
We need a directory to put all build output there, we are creating directory `build`

```shell
mkdir build
cd build
```

on Windows and build with Visual Studio
```shell
cmake -G "Visual Studio 17 2022" -S ..
cmake --build . --config Release
```


make

cmake -G "Visual Studio 17 2022" -S .. -B build
