%% clear
clear
close all hidden
clc

%% Settings

Settings.save_dir = 'C:\Users\quiri\UserData';         
Settings.sample = '100kOhm'; %A2-GatetoGate G0b
Settings.ADC = {1e6, 'off', 'off','off', 'off', 'off', 'off', 'off'};
Settings.auto = ''; % FEMTO
Settings.ADC_gain = [0 0 0 0 0 0 0 0]; % 2^N
Settings.get_sample_T = ''; % {'', 'Lakeshore336', 'Lakeshore325', 'Oxford_ITC'}
Settings.type = 'Waveform';
Settings.ADwin = 'ProII'; % GoldII or ProII
Settings.res4p = 0;     % 4 point measurement
Settings.T = [10];   %;

% NOTE: Be careful when choosing averaging: when effective sampling rate
% gets to high, filter might get unstable!
Timetrace.runtime = 2 ;      % s
Timetrace.scanrate = 300000;       % Hz
Timetrace.points_av = 60;        % points
Timetrace.process_number = 2;        
Timetrace.model ='ADwin';
Timetrace.process = 'Read_AI_fast_multi_fixed';

%% Initialize
Settings = Init(Settings);

%% Initialize ADwin
Settings = Init_ADwin(Settings, Timetrace);

%% set up sinewave
f_wanted = 23;
phi_shift = 0; %phase shift in degrees
RMS = 1; %RMS value of applied signal

% computes and compresses period length
wave_vec_length = Timetrace.scanrate/f_wanted;
repeats = 1;
while wave_vec_length > 10000
    wave_vec_length = wave_vec_length/10;
    repeats = repeats * 10;
end
wave_vec_length = round(wave_vec_length);

% generates 1 period sine and conveerts it to binned form
q = 1:wave_vec_length;
wave = RMS * sqrt(2) * cos(q*2*pi/wave_vec_length + phi_shift*2*pi/360);
wave_bin = convert_V_to_bin(wave, Settings.output_min, Settings.output_max, Settings.output_resolution);

% computes the actually applied frequency
actual_f = Timetrace.scanrate/(wave_vec_length * repeats);
fprintf("actual frequency = %f \n", actual_f)

% loads to ADwin
SetData_Double(1, wave_bin, 0);
Set_Par(23, numel(wave_bin));
Set_Par(30, repeats);
Set_Par(6, Settings.AO_address);

%% set up timetrace

% set parameters
[Timetrace.process_delay, ~] = get_delays(Timetrace.scanrate, 0, Settings.clockfrequency);  % get_delays
Timetrace.time_per_point = Timetrace.points_av / Timetrace.scanrate; % 1/sampling rate
Timetrace.sampling_rate = 1 / Timetrace.time_per_point;
Timetrace.runtime_counts = ceil(Timetrace.sampling_rate * Timetrace.runtime);
Set_Processdelay(2, Timetrace.process_delay);

% create time vector
Timetrace.time.ADwin = (0:Timetrace.time_per_point:(Timetrace.runtime_counts-1)*Timetrace.time_per_point)';

% set ADCs
Set_Par(10, Settings.input_resolution);

% set addresses
Set_Par(5,Settings.AI_address);
Set_Par(7,Settings.DIO_address);

% set amplifier settings
IV_gains = [0, 0, 0, 0, 0, 0, 0, 0]; %it will be calculated as 10^(-gain)
SetData_Double(15, IV_gains, 0);

% Inputs timetrace
Set_Par(21, Timetrace.points_av);

%% set ADC gains
SetData_Double(11, Settings.ADC_gain, 0);

%% set up filtering and mixing

% set realtime filering parameters
cutoff = 1;
order = 4;
[b, a] = butter(order,  cutoff / (Timetrace.sampling_rate / 2), 'low');
SetData_Double(3, [b, a], 0); % set filter parameters

% set up references
harmonic = 2;
q = 1:2*wave_vec_length; % 2*length to extend it for 90degree offset
q = q -Timetrace.points_av/(2*repeats) + 0.5 -1; % q - (fvsett/fvmeasure - 1)/2 subtracts shift of uneven setting/reading
%the additional -1 stems from the fact that voltage setting happens before mixing: implemented this way because then ADC can work during rest of code
internal_reference_wave =  sqrt(2) * cos(q*2*pi/wave_vec_length);
internal_reference_wave_harm =  sqrt(2) * cos(harmonic*q*2*pi/wave_vec_length);

% passes references to ADwin
SetData_Double(4, internal_reference_wave, 0);
SetData_Double(8, internal_reference_wave_harm, 0);
Set_Par(28, round(wave_vec_length/4)); % quarter wavelength (90degree shift)
Set_Par(31, round(wave_vec_length/(4*harmonic))); % harmonic quarter wavelength (90degree shift)

%% run measurement

% Calculates filters settling time
sys = tf(b, a, 1/Timetrace.sampling_rate);    % Discrete-time system with sample period 1/samplingrate
info = stepinfo(sys, 'SettlingTimeThreshold', 0.02); % Compute step response info with 2% settling threshold
settlingtime = info.SettlingTime; % Extract settling time

% adjusts runtime and runtimecount by adding settling time
settling_count = settlingtime * Timetrace.sampling_rate;
Timetrace.total_runtime = Timetrace.runtime + settlingtime;
Set_Par(29, settling_count);
Set_Par(14, Timetrace.runtime_counts + settling_count);

Start_Process(2);
tic;

% shows waitbar until measurment is complete.
wb = waitbar(0, 'Measurment in progress...');
while toc < Timetrace.total_runtime + 0.5 % waits 0.5s longer just to be sure its done
    elapsed = toc;
    waitbar(elapsed / (Timetrace.total_runtime+ 1), wb, sprintf('Measurment in progress...'));
    pause(0.05);  % smooth update
end
close(wb);
%% ADWIN readout and visualization

% set up figure
fig = figure('Name', 'Channel Results', 'NumberTitle', 'off', 'Position', [100, 100, 600, 700], 'Color', 'black');
output = "";

% reads result for each channel and averages it
for ch = 1:8
    offset = (ch-1)*4;
    inphase = GetData_Double(79, 0 + offset, 1)/Timetrace.runtime_counts;
    inphase_harm = GetData_Double(79, 2 + offset, 1)/Timetrace.runtime_counts;
    quadrature = GetData_Double(79, 1 + offset, 1)/Timetrace.runtime_counts;
    quadrature_harm = GetData_Double(79, 3 + offset, 1)/Timetrace.runtime_counts;
    
    R = sqrt(inphase^2 + quadrature^2);
    Theta = atan2(quadrature, inphase) * 180 / pi;
    R_harm = sqrt(inphase_harm^2 + quadrature_harm^2);
    Theta_harm = atan2(quadrature_harm, inphase_harm) * 180 / pi;
    
    % adds result to output string
    output = output + sprintf("Ch %d Inphase: %.5f    %d. Harm: %.5f\n", ch, inphase, harmonic, inphase_harm);
    output = output + sprintf("Ch %d Quadrature: %.5f    %d. Harm: %.5f\n", ch, quadrature, harmonic, quadrature_harm);
    output = output + sprintf("R: %.5f           %d. Harm: %.5f\n", R, harmonic, R_harm);
    output = output + sprintf("Theta (deg): %.2f     %d. Harm: %.2f\n\n", Theta, harmonic, Theta_harm);
end

% output window settings
uicontrol('Style', 'edit', 'Max', 10, 'Min', 1, 'String', output, 'Position', [10, 10, 580, 680], ...
    'BackgroundColor', 'black', 'ForegroundColor', 'white', 'FontName', 'Consolas', 'FontSize', 11, 'HorizontalAlignment', 'left');