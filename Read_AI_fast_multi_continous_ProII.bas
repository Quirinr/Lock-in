'<ADbasic Header, Headerversion 001.001>
' Process_Number                 = 2
' Initial_Processdelay           = 10000
' Eventsource                    = Timer
' Control_long_Delays_for_Stop   = No
' Priority                       = High
' Version                        = 1
' ADbasic_Version                = 6.4.0
' Optimize                       = Yes
' Optimize_Level                 = 4
' Stacksize                      = 1000
' Info_Last_Save                 = Q  Q\quiri
'<Header End>
'Gt_18b: ramps voltage on AO1, recording voltage on AI 1-4

'Inputs general:
'PAR_1 = Gain DAC 1
'PAR_2 = Gain DAC 2
'PAR_3 = Gain DAC 3
'PAR_4 = Gain DAC 4
'PAR_5 = Address AIN F4/18
'PAR_6 = Address AOUT 4/16
'PAR_7 = Address DIO-32
'PAR_10 = ADC resolution
'PAR_20 = Number of ADC pairs

'FPAR_26 = IV convert 1 autoranging 0 no, 1 lin, 2 log
'FPAR_27 = IV convert 2 autoranging 0 no, 1 lin, 2 log
'FPAR_28 = IV convert 3 autoranging 0 no, 1 lin, 2 log
'FPAR_29 = IV convert 4 autoranging 0 no, 1 lin, 2 log
'FPAR_44 = IV convert 5 autoranging 0 no, 1 lin, 2 log
'FPAR_45 = IV convert 6 autoranging 0 no, 1 lin, 2 log
'FPAR_46 = IV convert 7 autoranging 0 no, 1 lin, 2 log
'FPAR_47 = IV convert 8 autoranging 0 no, 1 lin, 2 log

'Measurement parameters:
'FPAR_1 = actual AI2 value in bin
'FPAR_2 = actual AI3 value in bin
'FPAR_3 = actual AI4 value in bin
'FPAR_4 = actual AI5 value in bin

'Inputs Gt:
'PAR_11 = initial voltage point
'PAR_12 = set voltage point
'PAR_13 = final voltage point
'PAR_14 = length of time array
'PAR_21 = no of points to average over
'PAR_22 = no of loops to wait before measure
'PAR_17 = loops to wait to limit AO rate
'PAR_18 = actual time counter
'PAR_19 = timecounter (here no meaning besides as a filtering index)
'PAR_27 = initial phase shift to reference signal
'PAR_28 = quarter period length of reference (used for cosine)
'PAR_29 = filter order
'PAR_31 = quarter period length of harmonic reference (used for cosine)
'measureflag = measurements flag

'Outputs:
'DATA_2 = ...

#INCLUDE ADwinPro_all.Inc

'used for all channels
DIM DATA_1[20000] as long  'voltage output array
DIM DATA_3[20] as float 'filter parameters
DIM DATA_4[200000] as float 'plain reference frequency for mixing
DIM DATA_8[200000] as float 'harmonic of plain reference frequency for mixing
DIM DATA_11[8] as long 'ADC gains
DIM DATA_15[8] as long 'IV gains
DIM DATA_10[8] as long 'read Data catch of channels
DIM DATA_16[16] as float 'readout constants and shifts
DIM DATA_17[8] as float 'summed up inputs of channels
DIM DATA_74[5] as long 'lookup table for idx1 to save operation in EVENT
DIM DATA_75[5] as long 'lookup table for idx2 to save operation in EVENT
DIM DATA_76[5] as long 'lookup table for idx3 to save operation in EVENT
DIM DATA_77[5] as long 'lookup table for idx4 to save operation in EVENT

'CHANNEL 1
DIM DATA_2[100] as float 'measured and mixed data inphase
DIM DATA_7[100] as float 'measured and mixed data quadrature
DIM DATA_6[100] as float 'inphase filtered signal
DIM DATA_5[100] as float 'quadrature filtered signal
DIM DATA_9[100] as float 'measured and mixed data inphase harmonic
DIM DATA_12[100] as float 'measured and mixed data quadrature harmonic
DIM DATA_13[100] as float 'inphase filtered signal harmonic
DIM DATA_14[100] as float 'quadrature filtered signal harmonic

'CHANNEL 2
DIM DATA_18[100] as float 'measured and mixed data inphase
DIM DATA_19[100] as float 'measured and mixed data quadrature
DIM DATA_20[100] as float 'inphase filtered signal
DIM DATA_21[100] as float 'quadrature filtered signal
DIM DATA_22[100] as float 'measured and mixed data inphase harmonic
DIM DATA_23[100] as float 'measured and mixed data quadrature harmonic
DIM DATA_24[100] as float 'inphase filtered signal harmonic
DIM DATA_25[100] as float 'quadrature filtered signal harmonic

'CHANNEL 3
DIM DATA_26[100] as float 'measured and mixed data inphase
DIM DATA_27[100] as float 'measured and mixed data quadrature
DIM DATA_28[100] as float 'inphase filtered signal
DIM DATA_29[100] as float 'quadrature filtered signal
DIM DATA_30[100] as float 'measured and mixed data inphase harmonic
DIM DATA_31[100] as float 'measured and mixed data quadrature harmonic
DIM DATA_32[100] as float 'inphase filtered signal harmonic
DIM DATA_33[100] as float 'quadrature filtered signal harmonic

'CHANNEL 4
DIM DATA_34[100] as float 'measured and mixed data inphase
DIM DATA_35[100] as float 'measured and mixed data quadrature
DIM DATA_36[100] as float 'inphase filtered signal
DIM DATA_37[100] as float 'quadrature filtered signal
DIM DATA_38[100] as float 'measured and mixed data inphase harmonic
DIM DATA_39[100] as float 'measured and mixed data quadrature harmonic
DIM DATA_40[100] as float 'inphase filtered signal harmonic
DIM DATA_41[100] as float 'quadrature filtered signal harmonic

'CHANNEL 5
DIM DATA_42[100] as float 'measured and mixed data inphase
DIM DATA_43[100] as float 'measured and mixed data quadrature
DIM DATA_44[100] as float 'inphase filtered signal
DIM DATA_45[100] as float 'quadrature filtered signal
DIM DATA_46[100] as float 'measured and mixed data inphase harmonic
DIM DATA_47[100] as float 'measured and mixed data quadrature harmonic
DIM DATA_48[100] as float 'inphase filtered signal harmonic
DIM DATA_49[100] as float 'quadrature filtered signal harmonic

'CHANNEL 6
DIM DATA_50[100] as float 'measured and mixed data inphase
DIM DATA_51[100] as float 'measured and mixed data quadrature
DIM DATA_52[100] as float 'inphase filtered signal
DIM DATA_53[100] as float 'quadrature filtered signal
DIM DATA_54[100] as float 'measured and mixed data inphase harmonic
DIM DATA_55[100] as float 'measured and mixed data quadrature harmonic
DIM DATA_56[100] as float 'inphase filtered signal harmonic
DIM DATA_57[100] as float 'quadrature filtered signal harmonic

'CHANNEL 7
DIM DATA_58[100] as float 'measured and mixed data inphase
DIM DATA_59[100] as float 'measured and mixed data quadrature
DIM DATA_60[100] as float 'inphase filtered signal
DIM DATA_61[100] as float 'quadrature filtered signal
DIM DATA_62[100] as float 'measured and mixed data inphase harmonic
DIM DATA_63[100] as float 'measured and mixed data quadrature harmonic
DIM DATA_64[100] as float 'inphase filtered signal harmonic
DIM DATA_65[100] as float 'quadrature filtered signal harmonic

'CHANNEL 8
DIM DATA_66[100] as float 'measured and mixed data inphase
DIM DATA_67[100] as float 'measured and mixed data quadrature
DIM DATA_68[100] as float 'inphase filtered signal
DIM DATA_69[100] as float 'quadrature filtered signal
DIM DATA_70[100] as float 'measured and mixed data inphase harmonic
DIM DATA_71[100] as float 'measured and mixed data quadrature harmonic
DIM DATA_72[100] as float 'inphase filtered signal harmonic
DIM DATA_73[100] as float 'quadrature filtered signal harmonic

DIM actual_V as long
DIM repeats as long

DIM avgcounter as long
DIM bin1 as long
DIM output_min, output_max, bin_size as float
DIM i as long 'for loop counter

DIM cosine_index as long
DIM cosine_index_harm as long
DIM idx1 as long
DIM idx2 as long
DIM idx3 as long
DIM idx4 as long
DIM save_index as long
DIM timecounter as long
DIM sine_index as long

INIT:
  'initialize counters and vectors
  avgcounter = 0
  
  'convert bin to V
  output_min = -10
  output_max = 9.99969
  bin_size = (output_max - output_min) / ((2^PAR_10))
  
  'calculations outside event block
  FOR i = 0 TO 7
    'DATA_16 is the readout constant in the first 8 entries and the outmin shift in the last 8
    DATA_16[i] = bin_size * (10^(-DATA_15[i])) / ((2^DATA_11[i]) * 64 * PAR_21) 'the power of 2 represents the ADC gain
    DATA_16[8+i] = output_min * (10^(-DATA_15[i])) / (2^(DATA_11[i]))  'the power of 2 represents the ADC gain
  NEXT
  
  
  'sets filter order 
  PAR_19 = 0 'par19 acts as filtering index
  
  'initializes arrays for filtering
  FOR i = 0 TO 5
    DATA_2[i] = 0
    DATA_7[i] = 0
    DATA_9[i] = 0
    DATA_12[i] = 0
    DATA_6[i] = 0
    DATA_5[i] = 0
    DATA_13[i] = 0
    DATA_14[i] = 0
    DATA_18[i] = 0
    DATA_19[i] = 0
    DATA_20[i] = 0
    DATA_21[i] = 0
    DATA_22[i] = 0
    DATA_23[i] = 0
    DATA_24[i] = 0
    DATA_25[i] = 0
    DATA_26[i] = 0
    DATA_27[i] = 0
    DATA_28[i] = 0
    DATA_29[i] = 0
    DATA_30[i] = 0
    DATA_31[i] = 0
    DATA_32[i] = 0
    DATA_33[i] = 0
    DATA_34[i] = 0
    DATA_35[i] = 0
    DATA_36[i] = 0
    DATA_37[i] = 0
    DATA_38[i] = 0
    DATA_39[i] = 0
    DATA_40[i] = 0
    DATA_41[i] = 0
    DATA_42[i] = 0
    DATA_43[i] = 0
    DATA_44[i] = 0
    DATA_45[i] = 0
    DATA_46[i] = 0
    DATA_47[i] = 0
    DATA_48[i] = 0
    DATA_49[i] = 0
    DATA_50[i] = 0
    DATA_51[i] = 0
    DATA_52[i] = 0
    DATA_53[i] = 0
    DATA_54[i] = 0
    DATA_55[i] = 0
    DATA_56[i] = 0
    DATA_57[i] = 0
    DATA_58[i] = 0
    DATA_59[i] = 0
    DATA_60[i] = 0
    DATA_61[i] = 0
    DATA_62[i] = 0
    DATA_63[i] = 0
    DATA_64[i] = 0
    DATA_65[i] = 0
    DATA_66[i] = 0
    DATA_67[i] = 0
    DATA_68[i] = 0
    DATA_69[i] = 0
    DATA_70[i] = 0
    DATA_71[i] = 0
    DATA_72[i] = 0
    DATA_73[i] = 0
  NEXT
  
  DATA_17[0] = 0
  DATA_17[1] = 0
  DATA_17[2] = 0
  DATA_17[3] = 0
  DATA_17[4] = 0
  DATA_17[5] = 0
  DATA_17[6] = 0
  DATA_17[7] = 0
  
  DATA_74[0] = 4
  DATA_74[1] = 0
  DATA_74[2] = 1
  DATA_74[3] = 2
  DATA_74[4] = 3
  DATA_75[0] = 3
  DATA_75[1] = 4
  DATA_75[2] = 0
  DATA_75[3] = 1
  DATA_75[4] = 2
  DATA_76[0] = 2
  DATA_76[1] = 3
  DATA_76[2] = 4
  DATA_76[3] = 0
  DATA_76[4] = 1
  DATA_77[0] = 1
  DATA_77[1] = 2
  DATA_77[2] = 3
  DATA_77[3] = 4
  DATA_77[4] = 0
  
  'start first conversion
  P2_Read_ADCF8_24B(PAR_5, DATA_10, 0)
  P2_START_CONVF(Par_5, 0000000011111111b)
  
  'for setting the DAC
  repeats = 0 ' counter which counts repeats of each value in voltage array
  actual_V = DATA_1[0] 'starts at 0 since then you do not have to do Par_23 + 1 and save an operation
  PAR_25 = 0 'Par_25 acts as voltagecounter
  
  'set DAC to first value
  P2_Write_DAC(Par_6, 1, actual_V)
  P2_Write_DAC(Par_6, 2, actual_V)
  P2_Write_DAC(Par_6, 3, actual_V)
  P2_Write_DAC(Par_6, 4, actual_V)
  P2_Write_DAC(Par_6, 5, actual_V)
  P2_Write_DAC(Par_6, 6, actual_V)
  P2_Write_DAC(Par_6, 7, actual_V)
  P2_Write_DAC(Par_6, 8, actual_V)
  P2_Start_DAC(PAR_6)
  
  P2_WAIT_EOC(11b)
  
EVENT:
  
  'how does it work? does it wait?? until conversion or does it run parallel to code?
  P2_Read_ADCF8_24B(PAR_5, DATA_10, 0) 'whats the 3. input for?
  P2_START_CONVF(Par_5, 0000000011111111b) 'there was 11b
  
  'if repeated enough, new voltage will be set
  IF (repeats = PAR_30) THEN
    P2_Write_DAC(Par_6, 1, DATA_1[PAR_25]) 'Par_25 acts as voltagecounter
    P2_Write_DAC(Par_6, 2, DATA_1[PAR_25]) 'Par_25 acts as voltagecounter
    P2_Write_DAC(Par_6, 3, DATA_1[PAR_25]) 'Par_25 acts as voltagecounter
    P2_Write_DAC(Par_6, 4, DATA_1[PAR_25]) 'Par_25 acts as voltagecounter
    P2_Write_DAC(Par_6, 5, DATA_1[PAR_25]) 'Par_25 acts as voltagecounter
    P2_Write_DAC(Par_6, 6, DATA_1[PAR_25]) 'Par_25 acts as voltagecounter
    P2_Write_DAC(Par_6, 7, DATA_1[PAR_25]) 'Par_25 acts as voltagecounter
    P2_Write_DAC(Par_6, 8, DATA_1[PAR_25]) 'Par_25 acts as voltagecounter
    P2_Start_DAC(PAR_6)
    
    PAR_25 = Par_25 + 1
    repeats = 0
    
    IF (PAR_25 = PAR_23) THEN
      PAR_25 = 0
    ENDIF
  ENDIF
  
  'here the input gets summed up for each channel
  DATA_17[0] = DATA_17[0] + DATA_10[0]
  DATA_17[1] = DATA_17[1] + DATA_10[1]
  DATA_17[2] = DATA_17[2] + DATA_10[2]
  DATA_17[3] = DATA_17[3] + DATA_10[3]
  DATA_17[4] = DATA_17[4] + DATA_10[4]
  DATA_17[5] = DATA_17[5] + DATA_10[5]
  DATA_17[6] = DATA_17[6] + DATA_10[6]
  DATA_17[7] = DATA_17[7] + DATA_10[7]
  
  avgcounter = avgcounter + 1
  
  
  'get averaging
  IF(avgcounter = PAR_21) THEN
    
    'here the averaging and other operations happen: summed inputs * constant1 + constant2 (constants calculated in INIT)
    DATA_17[0] = (DATA_17[0] * DATA_16[0]) + DATA_16[8]
    DATA_17[1] = (DATA_17[1] * DATA_16[1]) + DATA_16[9]
    DATA_17[2] = (DATA_17[2] * DATA_16[2]) + DATA_16[10]
    DATA_17[3] = (DATA_17[3] * DATA_16[3]) + DATA_16[11]
    DATA_17[4] = (DATA_17[4] * DATA_16[4]) + DATA_16[12]
    DATA_17[5] = (DATA_17[5] * DATA_16[5]) + DATA_16[13]
    DATA_17[6] = (DATA_17[6] * DATA_16[6]) + DATA_16[14]
    DATA_17[7] = (DATA_17[7] * DATA_16[7]) + DATA_16[15] 
    
    'indexes are being set
    sine_index = PAR_25 -1
    cosine_index = PAR_25 + PAR_28 -1 
    cosine_index_harm = PAR_25 + PAR_31 -1
    idx1 = DATA_74[PAR_19]
    idx2 = DATA_75[PAR_19]
    idx3 = DATA_76[PAR_19]
    idx4 = DATA_77[PAR_19]
     
    
    'Filtering for all Channels:
    
    'CHANNEL 1
    DATA_2[PAR_19]= DATA_17[0] * DATA_4[sine_index] 'mixing with plain sine
    DATA_7[PAR_19]= DATA_17[0] * DATA_4[cosine_index] 'mixing with plain cos
    DATA_9[PAR_19]= DATA_17[0] * DATA_8[sine_index] 'mixing with harmonic sine
    DATA_12[PAR_19]= DATA_17[0] * DATA_8[cosine_index_harm] 'mixing with harmonic cos
    'realtime filtering
    DATA_6[PAR_19] = DATA_3[0]*DATA_2[PAR_19] + DATA_3[1]*DATA_2[idx1] + DATA_3[2]*DATA_2[idx2] + DATA_3[3]*DATA_2[idx3] + DATA_3[4]*DATA_2[idx4] - DATA_3[6]*DATA_6[idx1] - DATA_3[7]*DATA_6[idx2] - DATA_3[8]*DATA_6[idx3] - DATA_3[9]*DATA_6[idx4]
    DATA_5[PAR_19] = DATA_3[0]*DATA_7[PAR_19] + DATA_3[1]*DATA_7[idx1] + DATA_3[2]*DATA_7[idx2] + DATA_3[3]*DATA_7[idx3] + DATA_3[4]*DATA_7[idx4] - DATA_3[6]*DATA_5[idx1] - DATA_3[7]*DATA_5[idx2] - DATA_3[8]*DATA_5[idx3] - DATA_3[9]*DATA_5[idx4]
    DATA_13[PAR_19] = DATA_3[0]*DATA_9[PAR_19] + DATA_3[1]*DATA_9[idx1] + DATA_3[2]*DATA_9[idx2] + DATA_3[3]*DATA_9[idx3] + DATA_3[4]*DATA_9[idx4] - DATA_3[6]*DATA_13[idx1] - DATA_3[7]*DATA_13[idx2] - DATA_3[8]*DATA_13[idx3] - DATA_3[9]*DATA_13[idx4]
    DATA_14[PAR_19] = DATA_3[0]*DATA_12[PAR_19] + DATA_3[1]*DATA_12[idx1] + DATA_3[2]*DATA_12[idx2] + DATA_3[3]*DATA_12[idx3] + DATA_3[4]*DATA_12[idx4] - DATA_3[6]*DATA_14[idx1] - DATA_3[7]*DATA_14[idx2] - DATA_3[8]*DATA_14[idx3] - DATA_3[9]*DATA_14[idx4]
    
    'CHANNEL 2
    DATA_18[PAR_19]= DATA_17[1] * DATA_4[sine_index] 'mixing with plain sine
    DATA_19[PAR_19]= DATA_17[1] * DATA_4[cosine_index] 'mixing with plain cos
    DATA_22[PAR_19]= DATA_17[1] * DATA_8[sine_index] 'mixing with harmonic sine
    DATA_23[PAR_19]= DATA_17[1] * DATA_8[cosine_index_harm] 'mixing with harmonic cos
    'realtime filtering
    DATA_20[PAR_19] = DATA_3[0]*DATA_18[PAR_19] + DATA_3[1]*DATA_18[idx1] + DATA_3[2]*DATA_18[idx2] + DATA_3[3]*DATA_18[idx3] + DATA_3[4]*DATA_18[idx4] - DATA_3[6]*DATA_20[idx1] - DATA_3[7]*DATA_20[idx2] - DATA_3[8]*DATA_20[idx3] - DATA_3[9]*DATA_20[idx4]
    DATA_21[PAR_19] = DATA_3[0]*DATA_19[PAR_19] + DATA_3[1]*DATA_19[idx1] + DATA_3[2]*DATA_19[idx2] + DATA_3[3]*DATA_19[idx3] + DATA_3[4]*DATA_19[idx4] - DATA_3[6]*DATA_21[idx1] - DATA_3[7]*DATA_21[idx2] - DATA_3[8]*DATA_21[idx3] - DATA_3[9]*DATA_21[idx4]
    DATA_24[PAR_19] = DATA_3[0]*DATA_22[PAR_19] + DATA_3[1]*DATA_22[idx1] + DATA_3[2]*DATA_22[idx2] + DATA_3[3]*DATA_22[idx3] + DATA_3[4]*DATA_22[idx4] - DATA_3[6]*DATA_24[idx1] - DATA_3[7]*DATA_24[idx2] - DATA_3[8]*DATA_24[idx3] - DATA_3[9]*DATA_24[idx4]
    DATA_25[PAR_19] = DATA_3[0]*DATA_23[PAR_19] + DATA_3[1]*DATA_23[idx1] + DATA_3[2]*DATA_23[idx2] + DATA_3[3]*DATA_23[idx3] + DATA_3[4]*DATA_23[idx4] - DATA_3[6]*DATA_25[idx1] - DATA_3[7]*DATA_25[idx2] - DATA_3[8]*DATA_25[idx3] - DATA_3[9]*DATA_25[idx4]
    
    'CHANNEL 3
    DATA_26[PAR_19]= DATA_17[2] * DATA_4[sine_index] 'mixing with plain sine
    DATA_27[PAR_19]= DATA_17[2] * DATA_4 [cosine_index] 'mixing with plain cos
    DATA_30[PAR_19]= DATA_17[2] * DATA_8[sine_index] 'mixing with harmonic sine
    DATA_31[PAR_19]= DATA_17[2] * DATA_8[cosine_index_harm] 'mixing with harmonic cos
    'realtime filtering
    DATA_28[PAR_19] = DATA_3[0]*DATA_26[PAR_19] + DATA_3[1]*DATA_26[idx1] + DATA_3[2]*DATA_26[idx2] + DATA_3[3]*DATA_26[idx3] + DATA_3[4]*DATA_26[idx4] - DATA_3[6]*DATA_28[idx1] - DATA_3[7]*DATA_28[idx2] - DATA_3[8]*DATA_28[idx3] - DATA_3[9]*DATA_28[idx4]
    DATA_29[PAR_19] = DATA_3[0]*DATA_27[PAR_19] + DATA_3[1]*DATA_27[idx1] + DATA_3[2]*DATA_27[idx2] + DATA_3[3]*DATA_27[idx3] + DATA_3[4]*DATA_27[idx4] - DATA_3[6]*DATA_29[idx1] - DATA_3[7]*DATA_29[idx2] - DATA_3[8]*DATA_29[idx3] - DATA_3[9]*DATA_29[idx4]
    DATA_32[PAR_19] = DATA_3[0]*DATA_30[PAR_19] + DATA_3[1]*DATA_30[idx1] + DATA_3[2]*DATA_30[idx2] + DATA_3[3]*DATA_30[idx3] + DATA_3[4]*DATA_30[idx4] - DATA_3[6]*DATA_32[idx1] - DATA_3[7]*DATA_32[idx2] - DATA_3[8]*DATA_32[idx3] - DATA_3[9]*DATA_32[idx4]
    DATA_33[PAR_19] = DATA_3[0]*DATA_31[PAR_19] + DATA_3[1]*DATA_31[idx1] + DATA_3[2]*DATA_31[idx2] + DATA_3[3]*DATA_31[idx3] + DATA_3[4]*DATA_31[idx4] - DATA_3[6]*DATA_33[idx1] - DATA_3[7]*DATA_33[idx2] - DATA_3[8]*DATA_33[idx3] - DATA_3[9]*DATA_33[idx4]
    
    'CHANNEL 4
    DATA_34[PAR_19]= DATA_17[3] * DATA_4[sine_index] 'mixing with plain sine
    DATA_35[PAR_19]= DATA_17[3] * DATA_4 [cosine_index] 'mixing with plain cos
    DATA_38[PAR_19]= DATA_17[3] * DATA_8[sine_index] 'mixing with harmonic sine
    DATA_39[PAR_19]= DATA_17[3] * DATA_8[cosine_index_harm] 'mixing with harmonic cos
    'realtime filtering
    DATA_36[PAR_19] = DATA_3[0]*DATA_34[PAR_19] + DATA_3[1]*DATA_34[idx1] + DATA_3[2]*DATA_34[idx2] + DATA_3[3]*DATA_34[idx3] + DATA_3[4]*DATA_34[idx4] - DATA_3[6]*DATA_36[idx1] - DATA_3[7]*DATA_36[idx2] - DATA_3[8]*DATA_36[idx3] - DATA_3[9]*DATA_36[idx4]
    DATA_37[PAR_19] = DATA_3[0]*DATA_35[PAR_19] + DATA_3[1]*DATA_35[idx1] + DATA_3[2]*DATA_35[idx2] + DATA_3[3]*DATA_35[idx3] + DATA_3[4]*DATA_35[idx4] - DATA_3[6]*DATA_37[idx1] - DATA_3[7]*DATA_37[idx2] - DATA_3[8]*DATA_37[idx3] - DATA_3[9]*DATA_37[idx4]
    DATA_40[PAR_19] = DATA_3[0]*DATA_38[PAR_19] + DATA_3[1]*DATA_38[idx1] + DATA_3[2]*DATA_38[idx2] + DATA_3[3]*DATA_38[idx3] + DATA_3[4]*DATA_38[idx4] - DATA_3[6]*DATA_40[idx1] - DATA_3[7]*DATA_40[idx2] - DATA_3[8]*DATA_40[idx3] - DATA_3[9]*DATA_40[idx4]
    DATA_41[PAR_19] = DATA_3[0]*DATA_39[PAR_19] + DATA_3[1]*DATA_39[idx1] + DATA_3[2]*DATA_39[idx2] + DATA_3[3]*DATA_39[idx3] + DATA_3[4]*DATA_39[idx4] - DATA_3[6]*DATA_41[idx1] - DATA_3[7]*DATA_41[idx2] - DATA_3[8]*DATA_41[idx3] - DATA_3[9]*DATA_41[idx4]
    
    'CHANNEL 5
    DATA_42[PAR_19]= DATA_17[4] * DATA_4[sine_index] 'mixing with plain sine
    DATA_43[PAR_19]= DATA_17[4] * DATA_4 [cosine_index] 'mixing with plain cos
    DATA_46[PAR_19]= DATA_17[4] * DATA_8[sine_index] 'mixing with harmonic sine
    DATA_47[PAR_19]= DATA_17[4] * DATA_8[cosine_index_harm] 'mixing with harmonic cos
    'realtime filtering
    DATA_44[PAR_19] = DATA_3[0]*DATA_42[PAR_19] + DATA_3[1]*DATA_42[idx1] + DATA_3[2]*DATA_42[idx2] + DATA_3[3]*DATA_42[idx3] + DATA_3[4]*DATA_42[idx4] - DATA_3[6]*DATA_44[idx1] - DATA_3[7]*DATA_44[idx2] - DATA_3[8]*DATA_44[idx3] - DATA_3[9]*DATA_44[idx4]
    DATA_45[PAR_19] = DATA_3[0]*DATA_43[PAR_19] + DATA_3[1]*DATA_43[idx1] + DATA_3[2]*DATA_43[idx2] + DATA_3[3]*DATA_43[idx3] + DATA_3[4]*DATA_43[idx4] - DATA_3[6]*DATA_45[idx1] - DATA_3[7]*DATA_45[idx2] - DATA_3[8]*DATA_45[idx3] - DATA_3[9]*DATA_45[idx4]
    DATA_48[PAR_19] = DATA_3[0]*DATA_46[PAR_19] + DATA_3[1]*DATA_46[idx1] + DATA_3[2]*DATA_46[idx2] + DATA_3[3]*DATA_46[idx3] + DATA_3[4]*DATA_46[idx4] - DATA_3[6]*DATA_48[idx1] - DATA_3[7]*DATA_48[idx2] - DATA_3[8]*DATA_48[idx3] - DATA_3[9]*DATA_48[idx4]
    DATA_49[PAR_19] = DATA_3[0]*DATA_47[PAR_19] + DATA_3[1]*DATA_47[idx1] + DATA_3[2]*DATA_47[idx2] + DATA_3[3]*DATA_47[idx3] + DATA_3[4]*DATA_47[idx4] - DATA_3[6]*DATA_49[idx1] - DATA_3[7]*DATA_49[idx2] - DATA_3[8]*DATA_49[idx3] - DATA_3[9]*DATA_49[idx4]
    
    'CHANNEL 6
    DATA_50[PAR_19]= DATA_17[5] * DATA_4[sine_index] 'mixing with plain sine
    DATA_51[PAR_19]= DATA_17[5] * DATA_4 [cosine_index] 'mixing with plain cos
    DATA_54[PAR_19]= DATA_17[5] * DATA_8[sine_index] 'mixing with harmonic sine
    DATA_55[PAR_19]= DATA_17[5] * DATA_8[cosine_index_harm] 'mixing with harmonic cos
    'realtime filtering
    DATA_52[PAR_19] = DATA_3[0]*DATA_50[PAR_19] + DATA_3[1]*DATA_50[idx1] + DATA_3[2]*DATA_50[idx2] + DATA_3[3]*DATA_50[idx3] + DATA_3[4]*DATA_50[idx4] - DATA_3[6]*DATA_52[idx1] - DATA_3[7]*DATA_52[idx2] - DATA_3[8]*DATA_52[idx3] - DATA_3[9]*DATA_52[idx4]
    DATA_53[PAR_19] = DATA_3[0]*DATA_51[PAR_19] + DATA_3[1]*DATA_51[idx1] + DATA_3[2]*DATA_51[idx2] + DATA_3[3]*DATA_51[idx3] + DATA_3[4]*DATA_51[idx4] - DATA_3[6]*DATA_53[idx1] - DATA_3[7]*DATA_53[idx2] - DATA_3[8]*DATA_53[idx3] - DATA_3[9]*DATA_53[idx4]
    DATA_56[PAR_19] = DATA_3[0]*DATA_54[PAR_19] + DATA_3[1]*DATA_54[idx1] + DATA_3[2]*DATA_54[idx2] + DATA_3[3]*DATA_54[idx3] + DATA_3[4]*DATA_54[idx4] - DATA_3[6]*DATA_56[idx1] - DATA_3[7]*DATA_56[idx2] - DATA_3[8]*DATA_56[idx3] - DATA_3[9]*DATA_56[idx4]
    DATA_57[PAR_19] = DATA_3[0]*DATA_55[PAR_19] + DATA_3[1]*DATA_55[idx1] + DATA_3[2]*DATA_55[idx2] + DATA_3[3]*DATA_55[idx3] + DATA_3[4]*DATA_55[idx4] - DATA_3[6]*DATA_57[idx1] - DATA_3[7]*DATA_57[idx2] - DATA_3[8]*DATA_57[idx3] - DATA_3[9]*DATA_57[idx4]
    
    'CHANNEL 7
    DATA_58[PAR_19]= DATA_17[6] * DATA_4[sine_index] 'mixing with plain sine
    DATA_59[PAR_19]= DATA_17[6] * DATA_4 [cosine_index] 'mixing with plain cos
    DATA_62[PAR_19]= DATA_17[6] * DATA_8[sine_index] 'mixing with harmonic sine
    DATA_63[PAR_19]= DATA_17[6] * DATA_8[cosine_index_harm] 'mixing with harmonic cos
    'realtime filtering
    DATA_60[PAR_19] = DATA_3[0]*DATA_58[PAR_19] + DATA_3[1]*DATA_58[idx1] + DATA_3[2]*DATA_58[idx2] + DATA_3[3]*DATA_58[idx3] + DATA_3[4]*DATA_58[idx4] - DATA_3[6]*DATA_60[idx1] - DATA_3[7]*DATA_60[idx2] - DATA_3[8]*DATA_60[idx3] - DATA_3[9]*DATA_60[idx4]
    DATA_61[PAR_19] = DATA_3[0]*DATA_59[PAR_19] + DATA_3[1]*DATA_59[idx1] + DATA_3[2]*DATA_59[idx2] + DATA_3[3]*DATA_59[idx3] + DATA_3[4]*DATA_59[idx4] - DATA_3[6]*DATA_61[idx1] - DATA_3[7]*DATA_61[idx2] - DATA_3[8]*DATA_61[idx3] - DATA_3[9]*DATA_61[idx4]
    DATA_64[PAR_19] = DATA_3[0]*DATA_62[PAR_19] + DATA_3[1]*DATA_62[idx1] + DATA_3[2]*DATA_62[idx2] + DATA_3[3]*DATA_62[idx3] + DATA_3[4]*DATA_62[idx4] - DATA_3[6]*DATA_64[idx1] - DATA_3[7]*DATA_64[idx2] - DATA_3[8]*DATA_64[idx3] - DATA_3[9]*DATA_64[idx4]
    DATA_65[PAR_19] = DATA_3[0]*DATA_63[PAR_19] + DATA_3[1]*DATA_63[idx1] + DATA_3[2]*DATA_63[idx2] + DATA_3[3]*DATA_63[idx3] + DATA_3[4]*DATA_63[idx4] - DATA_3[6]*DATA_65[idx1] - DATA_3[7]*DATA_65[idx2] - DATA_3[8]*DATA_65[idx3] - DATA_3[9]*DATA_65[idx4]
    
    'CHANNEL 8
    DATA_66[PAR_19]= DATA_17[7] * DATA_4[sine_index] 'mixing with plain sine
    DATA_67[PAR_19]= DATA_17[7] * DATA_4[cosine_index] 'mixing with plain cos
    DATA_70[PAR_19]= DATA_17[7] * DATA_8[sine_index] 'mixing with harmonic sine
    DATA_71[PAR_19]= DATA_17[7] * DATA_8[cosine_index_harm] 'mixing with harmonic cos
    'realtime filtering
    DATA_68[PAR_19] = DATA_3[0]*DATA_66[PAR_19] + DATA_3[1]*DATA_66[idx1] + DATA_3[2]*DATA_66[idx2] + DATA_3[3]*DATA_66[idx3] + DATA_3[4]*DATA_66[idx4] - DATA_3[6]*DATA_68[idx1] - DATA_3[7]*DATA_68[idx2] - DATA_3[8]*DATA_68[idx3] - DATA_3[9]*DATA_68[idx4]
    DATA_69[PAR_19] = DATA_3[0]*DATA_67[PAR_19] + DATA_3[1]*DATA_67[idx1] + DATA_3[2]*DATA_67[idx2] + DATA_3[3]*DATA_67[idx3] + DATA_3[4]*DATA_67[idx4] - DATA_3[6]*DATA_69[idx1] - DATA_3[7]*DATA_69[idx2] - DATA_3[8]*DATA_69[idx3] - DATA_3[9]*DATA_69[idx4]
    DATA_72[PAR_19] = DATA_3[0]*DATA_70[PAR_19] + DATA_3[1]*DATA_70[idx1] + DATA_3[2]*DATA_70[idx2] + DATA_3[3]*DATA_70[idx3] + DATA_3[4]*DATA_70[idx4] - DATA_3[6]*DATA_72[idx1] - DATA_3[7]*DATA_72[idx2] - DATA_3[8]*DATA_72[idx3] - DATA_3[9]*DATA_72[idx4]
    DATA_73[PAR_19] = DATA_3[0]*DATA_71[PAR_19] + DATA_3[1]*DATA_71[idx1] + DATA_3[2]*DATA_71[idx2] + DATA_3[3]*DATA_71[idx3] + DATA_3[4]*DATA_71[idx4] - DATA_3[6]*DATA_73[idx1] - DATA_3[7]*DATA_73[idx2] - DATA_3[8]*DATA_73[idx3] - DATA_3[9]*DATA_73[idx4]
    
    
    avgcounter = 0
    DATA_17[0] = 0
    DATA_17[1] = 0
    DATA_17[2] = 0
    DATA_17[3] = 0
    DATA_17[4] = 0
    DATA_17[5] = 0
    DATA_17[6] = 0
    DATA_17[7] = 0
    
    PAR_19 = PAR_19 + 1
    
    IF (PAR_19 = 5) THEN
      PAR_19 = 0
    ENDIF
  ENDIF
  
  repeats = repeats + 1
FINISH:
