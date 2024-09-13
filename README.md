# stam2003-godot

### abstract
'Real-Time Fluid Dynamics for Games' (Stam 2003) - was published 20 years ago. the goal of this repo was to explore the scope of scale on todays hardware vs 2003

![fire](images/007_squareb.gif)


### results
using flops as a measure, i found todays hardware getting ~15% of its theortical throughput. i put this down to cache misses and the challenges with getting theortitical throughput in real worl scenarios with todays gpu hardware. this is afer many optimizations (shaders, 16bit, SMIT, combining textures). 

| | GFLOPS | multiple | cells | 2d | 3d | | actual 2d | actual multiple |
|-|-|-|-|-|-|-|-|-|
| p4 3.2gz | 0.773 | 1 |  4,096 | 64 | n/a | | 64
| 2023 MacBook Pro m3 | 16,400 | 22,373x | 92m | 9,572 | 450 | | 4096 | 4096x (18%)
| 2022 RTX 4090 | 82,580 | 112,660x | 461m | 21,481 | 772 | | 8192 | 16,384x (15%)
| 20 years of 2x every 2y | 791 | 1024x | 4.2m | 2,048 | 161
| 20 years of 2x every 1.5y | 7978 | 10,321x | 42m | 6,501 | 348

-----

## detailed results

these are results from each optimization, see branches for different code implementations


### multigrid 2d
| | 64 | 128 | 256 | 512 | 1024 | 2048 | 4096 | 8192 | 16,384  | 32,768 |
|-|-|-|-|-|-|-|-|-|-|-|
|M3| 2142 | 2132 | 2062 | 1649 | 767 | 141 |35 | 9 | 2 | xxx |
|4090| 3848 | 3775 | 3726 | 3267 | 3010 | 984 | 253 | 61 | 7 | xxx |


### 3d
| | 64 | 128 | 200| 256 | 400 | 512 | 1024 | 
|-|-|-|-|-|-|-|-|
|M3| 1303 | 184 | 49 | 24 | 6 | 3 | <1 | 
|4090| 4480 | 1092 | 290 |142 | 37 | 11 | crash | 


### 007 combine textures
| | 64 | 128 | 256 | 512 | 1024 | 2048 | 4096 | 8192 | 16,384  | 32,768 |
|-|-|-|-|-|-|-|-|-|-|-|
|M3| 2110 | 2164 | 2211 | 1779 | 846 | 143 | 32 | 8 | 2 | xxx |
|4090| 4406 | 4372 | 4352 | 4322 | 3273 | 968 | 251 | 60 | 7 | xxx |


### 006 SMIT + boundary optimizations
| | 64 | 128 | 256 | 512 | 1024 | 2048 | 4096 | 8192 | 16,384  | 32,768 |
|-|-|-|-|-|-|-|-|-|-|-|
|M3| 1460 | 1613 | 1526 | 1087 | 504 | 133 | 27 | 7 | 2 | xxx |
|4090| 3416 | 3441 | 3472 | 3448 | 2245 | 669 | 174 | 41 | 10 | xxx |

### 005 16 bit, 8 bit state & ignition
| | 64 | 128 | 256 | 512 | 1024 | 2048 | 4096 | 8192 | 16,384  | 32,768 |
|-|-|-|-|-|-|-|-|-|-|-|
|M3| 880 | 880 | 877 | 1034 | 387 | 95 | 21 | 5 | 2 | xxx |
|4090| 3330 | 3371 | 3471 | 3394 | 1723 | 481 | 123 | 28 | 7 | xxx |


### 004

| | 64 | 128 | 256 | 512 | 1024 | 2048 | 4096 | 8192 | 16,384  | 32,768 |
|-|-|-|-|-|-|-|-|-|-|-|
|M3| 1760 | 1746 | 1637 | 1014 | 343 | 55 | 13 | 4 | 1 | xxx |
|4090| 3344 | 3444 | xxx | 3410 | 1600 | 436 | 73 | 22 | 3 | xxx |


### 002

| | 64 | 128 | 256 | 512 | 1024 | 2048 | 4096 | 8192 | 16,384  | 32,768 |
|-|-|-|-|-|-|-|-|-|-|-|
|M3| 705 | 705 | 705 | 705 | 330 | 52 | 12 | 3 | 1 | crash |
|4090| 4040 | 4128 | 4049 | 4094 | 1838 | 413 | 34 | 9 | 2 | crash |



	pow(2,6), #64
	pow(2,7), #128
	pow(2,8), #256
	pow(2,9), #512
	pow(2,10), #1024
	pow(2,11), #2048
	pow(2,12), #4096
	pow(2,13), #8192
	pow(2,14), #16,384
	#pow(2,15), #32,768