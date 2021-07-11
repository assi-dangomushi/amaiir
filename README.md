# amaiir
iir Xover program  
input: stdin 32bit int 2ch  
output: stdout 32bit int 8ch  

## inatall

install nim

nim c -d:release amaiir.nim

## Usage
amaiir confFilename 

## Notice
ChannelMapping is Changed(2021/02/23)

0: LF  
1: RF  
2: LB  
3: RB  
4: CF  
5: LFE  
6: LS  
7: RS  

Use with hdmi_play2.bin or ALSA.
Not use with hdmi_play.bin !

