%% clear
clear
close all hidden
clc
%% Settings
Settings.save_dir =  'C:\Samples\Fred\testing\24Bit\';
Settings.sample = '3.9kohm_lp_3_1000_gain';
Settings.ADC_gain = [0 0 0 0 0 0 0 0]; % 2^N
Settings.get_sample_T = ''; % {'', 'Lakeshore336', 'Lakeshore325', 'Oxford_ITC'}
Settings.type = 'Timetrace'; % (.type influences only plot labels)
Settings.ADwin = 'ProII'; % GoldII or ProII

Timetrace.runtime = 10;      % s
Timetrace.scanrate = 500000;       % Hz
Timetrace.points_av = 100;        % points
Timetrace.process_number = 2;
Timetrace.model ='ADwin';
Timetrace.process = 'Lock-in';

Waveform.output = 2;
%Waveform.process = 'Waveform_AO'; %clearly wrong, doesnt take lock-in :: How to do multiple ones running the file
%Waveform.process_number = 2;

%% Initialize
Settings = Init(Settings);
%% Initialize ADwin
Settings = Init_ADwin(Settings, Timetrace);

%% set up timetrace
% set parameters
[Timetrace.process_delay, ~] = get_delays(Timetrace.scanrate, 0, Settings.clockfrequency);  % get_delays
Timetrace.process_delay;
Timetrace.time_per_point = Timetrace.points_av / Timetrace.scanrate; % 1/sampling rate
Timetrace.sampling_rate = 1 / Timetrace.time_per_point;
Timetrace.runtime_counts = ceil(Timetrace.sampling_rate * Timetrace.runtime);

% create time vector
Timetrace.time.ADwin = (0:Timetrace.time_per_point:(Timetrace.runtime_counts-1)*Timetrace.time_per_point)';

% set ADCs
Set_Par(10, Settings.input_resolution);


% set addresses
Set_Par(5,Settings.AI_address);
Set_Par(6,Settings.AO_address);
Set_Par(7,Settings.DIO_address); %(needed?)

% set amplifier settings
Set_FPar(27, 0);

% Inputs timetrace
Set_Par(14, Timetrace.runtime_counts);
Set_Par(21, Timetrace.points_av);

Set_Processdelay(2, Timetrace.process_delay);
%% set up sinewave

Processdelay = Get_Processdelay(2);
f_wanted = 5;
phi_shift = 0; %phase shift in degrees
Amplitude = 1; %Amplitude of sinewave

f_process = Settings.clockfrequency/(Processdelay * 10); % *10 because in ADBASIC only every 10th processcycle the voltage gets changed
wave_vec_length = f_process/f_wanted;
wave_vec_length = round(wave_vec_length)
q = 1:wave_vec_length;
wave = Amplitude * sin(q*2*pi/wave_vec_length + phi_shift*2*pi/360); %NOTE: Rounding Error, TODO: calculate it
wave_bin = convert_V_to_bin(wave, Settings.output_min, Settings.output_max, Settings.output_resolution);

SetData_Double(1, wave_bin, 0);
Set_Par(8, Waveform.output);
Set_Par(23,numel(wave_bin)); 


%% set ADC gains
SetData_Double(11, Settings.ADC_gain, 1);
%% run measurement
Start_Process(2);

%% get current and show plot
Settings.N_ADC = 1;
Settings.ADC_idx = 1;
Timetrace = Realtime_timetrace(Settings, Timetrace, Settings.type);

%% Mixing
measured_signal = GetData_Double(2, 0, Timetrace.sampling_rate * Timetrace.runtime); %extracts input signal from Adwin

%Idea: since sine is set at 50kHz but measured signal at 5kHz -> sine must be changed accordingly
%calculates how many datapoints in measured_signal represent 1 period
period_length = wave_vec_length * Timetrace.sampling_rate / 50000; % the 50000 stands for the rate at which the individual wave entries are applied (voltage steps)
q = 1:length(measured_signal);%helper for sine multiplication

%mixes measured_signal with a sine of same freq as our initial wave
mixed_signal_inphase = measured_signal * Amplitude .* sin(q*2*pi/period_length + phi_shift*2*pi/360);
mixed_signal_quadrature = measured_signal * Amplitude .* sin(q*2*pi/period_length + pi/2 + phi_shift*2*pi/360);

%% Lock-in calculations

%filtered_signal_inphase = lowpass(mixed_signal_inphase,   1, Timetrace.sampling_rate); %non optimal, design filter yourself
%filtered_signal_quadrature = lowpass(mixed_signal_quadrature, 1, Timetrace.sampling_rate); %non optimal, design filter yourself

cutoff = 1;

% Design a 4th-order Butterworth lowpass filter
[b, a] = butter(4, cutoff / (Timetrace.sampling_rate / 2), 'low');

% Apply the filter to remove high frequencies
filtered_signal_inphase = filtfilt(b, a, mixed_signal_inphase);  % Zero-phase filtering
filtered_signal_quadrature = filtfilt(b, a, mixed_signal_quadrature);
%% 

filtered_signal_inphase_RMS = filtered_signal_inphase/sqrt(2);
filtered_signal_quadrature_RMS = filtered_signal_quadrature/sqrt(2);

R = sqrt(filtered_signal_inphase.^2 + filtered_signal_quadrature.^2);
Theta = atan(filtered_signal_quadrature ./filtered_signal_inphase);


%hold on
%plot(abs(fft(measured_signal)), LineStyle="-", Color= 'w')
%plot(abs(fft(mixed_signal_inphase)), LineStyle='-', Color='b')
%plot(abs(fft(filtered_signal_inphase)), LineStyle='-', Color='r')
%hold off


hold on
%plot(filtered_signal_inphase(1:2*round(period_length)))
%plot(filtered_signal_quadrature(1:2*round(period_length)))
%plot(Theta(1:2*round(period_length)))
%plot(R(1:2*round(period_length)))

plot(R)
%plot(Theta)
%plot(filtered_signal_inphase(1:500))
%plot(mixed_signal_inphase(1:500))
hold off

