# edrgen.py

This data generator is intended to generate data for the EDR demo

## Files
* `edrgen.py` - the data generator; run using python3. 
* `sqlstream.sql` - a script that tests performance using SQLstream
  * `sqlstream_cpp.sql` - includes reference to a C UDX for faster CSV parsing
* `flink.sql` - a script that tests performance using Flink. 

## Options

  * default arguments can be used to reproduce something like the original Cricket data
  * For help use `python3 edrgen.py --help`
  * Using default parameters on my 10 year old iMac it takes about 12 minutes to generate 1 hour of data (900k sessions, 4M flows)


## Data generated

### Sessions File

* We get one entry per session per period (roughly, each active session repeats every 2 minutes; occasional extra rows if the device moves).
* In the generated data the gaps between two rows from one session will be much more random than in the real data

### Flows File

* We get multiple entries per session, grouped together into a burst of several flows for one session
* Each entry is a separate flow sub-session(data-plane session) within the overall control-plane session
* The number of flows in each burst looks like this in the customer data:

```
occurs  # of sessions
2395706 1
1302098 2
585907 3
464875 4
268971 5
237492 6
138853 7
130045 8
92735 9
88689 10
64930 11
58755 12
42368 13
39573 14
31091 15
28891 16
23263 17
21500 18
17545 19
16768 20
14071 21
13276 22
11284 23
10731 24
9547 25
9146 26
8344 27
7864 28
7097 29
6944 30
6498 31
6363 32
5601 33
5330 34
5104 35
4643 36
4348 37
3977 38
3631 39
3514 40
3128 41
2762 42
2515 43
2292 44
2080 45
1866 46
1527 47
1333 48
1091 49
 933 50
 738 51
 579 52
 483 53
 403 54
 280 55
 220 56
 159 57
 133 58
 102 59
  82 60
  48 61
  47 62
  19 63
  17 64
  17 65
  21 66
  20 67
  14 68
   8 69
  10 70
   6 71
   8 72
   4 73
   8 74
  10 75
   2 76
   6 77
   2 78
   4 80
   4 81
   3 82
   3 83
   5 84
   1 85
   3 86
   2 87
   1 88
   1 89
   4 90
   4 91
   2 92
   6 93
   2 95
   2 96
   1 97
   2 98
   2 99
   1 101
   1 103
   1 104
   2 105
   1 108
   1 109
   2 110
   3 111
   2 112
   2 113
   1 114
   1 115
   2 118
   1 119
   1 121
   3 123
   1 128
   5 130
   2 132
   1 133
   1 134
   2 135
   1 136
   1 139
   1 144
   1 146
   2 147
   2 148
   2 151
   2 154
   1 155
   1 156
   1 160
   1 162
   2 164
   2 165
   1 167
   2 170
   1 176
   1 179
   1 181
   2 185
   2 187
   2 189
   2 190
   1 193
   1 195
   1 196
   1 201
   1 202
   1 203
   1 204
   1 208
   1 222
   1 224
   1 225
   1 229
   1 230
   2 235
   1 237
   1 242
   1 247
   1 249
   1 258
   1 259
   1 260
   1 262
   1 278
   1 299
   1 339
   1 377
   1 409
   1 427
   1 432
   1 651
   1 661
