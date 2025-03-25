%% clearDIO
clear
close all hidden
clc

%% Settings
Settings.save_dir =  'C:\Samples\Fred\testing\24Bit\';
Settings.sample = '3.9kohm_lp_3_1000_gain';
Settings.ADC_gain = [0 0 0 0 0 0 0 0]; % 2^N
Settings.get_sample_T = ''; % {'', 'Lakeshore336', 'Lakeshore325', 'Oxford_ITC'}
Settings.type = 'Timetrace';
Settings.ADwin = 'ProII'; % GoldII or ProII

Timetrace.runtime = 50;      % s
Timetrace.scanrate = 500000;       % Hz
Timetrace.points_av = 100;        % points
Timetrace.process_number = 2;
Timetrace.model ='ADwin';
Timetrace.process = 'Read_AI_fast_single';
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
Set_Par(7,Settings.DIO_address);

% set amplifier settings
Set_FPar(27, 0)

% Inputs timetrace
Set_Par(14, Timetrace.runtime_counts);
Set_Par(21, Timetrace.points_av);

%% set ADC gains
SetData_Double(11, Settings.ADC_gain, 1);

%% run measurement
Set_Processdelay(2, Timetrace.process_delay);
Start_Process(2);

Timetrace.index = 1;

%% get current and show plot
Settings.N_ADC = 1;
Settings.ADC_idx = 1;
Timetrace = Realtime_timetrace(Settings, Timetrace, Settings.type);

fprintf('done\n')
