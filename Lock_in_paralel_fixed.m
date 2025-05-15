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
Timetrace.scanrate = 100000;       % Hz
Timetrace.points_av = 20;        % points
Timetrace.process_number = 2;        
Timetrace.model ='ADwin';
Timetrace.process = 'Read_AI_fast_multi_fixed';

%% Initialize
Settings = Init(Settings);

%% Initialize ADwin
Settings = Init_ADwin(Settings, Timetrace);

%% set up sinewave
f_wanted = 12;
phi_shift = 0; %phase shift in degrees
Amplitude = 1;

Timetrace.process_delay = Settings.clockfrequency/Timetrace.scanrate; %computes process delay
Set_Processdelay(6, Timetrace.process_delay);

wave_vec_length = Timetrace.scanrate/f_wanted;
repeats = 1;

while wave_vec_length > 10000
    wave_vec_length = wave_vec_length/10;
    repeats = repeats * 10;
end

wave_vec_length = round(wave_vec_length);
q = 1:wave_vec_length;
wave = Amplitude * sqrt(2) * cos(q*2*pi/wave_vec_length + phi_shift*2*pi/360) + Amplitude * sqrt(2) * cos(q*4*pi/wave_vec_length + phi_shift*2*pi/360);
wave_bin = convert_V_to_bin(wave, Settings.output_min, Settings.output_max, Settings.output_resolution);

actual_f = Settings.clockfrequency/(wave_vec_length * repeats * Timetrace.process_delay);
fprintf("actual frequency = %f \n", actual_f)

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

%% set realtime filering parameters

harmonic = 2;   %IDEA: try demodulating harmonic with harmonic reference instead of normal one with DATA_2 abd 7 to localize the problem
cutoff = 1;
order = 4;

[b, a] = butter(order,  cutoff / (Timetrace.sampling_rate / 2), 'low');

% Convert to state-space or transfer function form
sys = tf(b, a, 1/Timetrace.sampling_rate);    % Discrete-time system with sample time 1/samplingrate
info = stepinfo(sys); % Compute step response info
settlingtime = info.SettlingTime; % Extract and display settling time
disp(['Settling Time: ' num2str(info.SettlingTime) ' seconds']);

%adjusts runtime and runtimecount by adding settling time
settled_count = settlingtime * Timetrace.sampling_rate;
Timetrace.runtime = Timetrace.runtime + settlingtime;
Set_Par(14, Timetrace.runtime_counts + settled_count);

%subtracts the shift introduced by zero order hold error
q = 1:4*wave_vec_length;
q = q - Settings.clockfrequency/(Timetrace.process_delay *2 * repeats * Timetrace.sampling_rate) -0.5; % q - ((fsett/fmeasure) -2)/2 (zero order hold error)
internal_reference_wave =  sqrt(2) * cos(q*2*pi/wave_vec_length + phi_shift*2*pi/360); %used in mixing
internal_reference_wave_harm =  sqrt(2) * cos(harmonic*q*2*pi/wave_vec_length + phi_shift*2*pi/360); %used in mixing with harmonic


Set_Par(28, round(wave_vec_length/4));
Set_Par(31, round(wave_vec_length/(4*harmonic)));
SetData_Double(3, [b, a], 0); %set filter parameters
SetData_Double(4, internal_reference_wave, 0); %defines normalized reference for mixing, multiple length to simplify cosine in ADBASIC
SetData_Double(8, internal_reference_wave_harm, 0); %defines normailzed harmonic reference for mixing, multiple length to simplify cosine in ADBASIC

%% run timetrace
Start_Process(2);

%shows waitbar until measurment is complete.
wb = waitbar(0, 'Measurment in progress...');
tic;
while toc < Timetrace.runtime + 0.5 %waits 0.5s longer just to be sure its done
    elapsed = toc;
    waitbar(elapsed / (Timetrace.runtime + 1), wb, sprintf('Measurment in progress...'));
    pause(0.05);  % smooth update
end
close(wb);
%% ADWIN readout and plot

fig = figure('Name', 'Channel Results', 'NumberTitle', 'off', 'Position', [100, 100, 600, 700], 'Color', 'black');
output = "";

% CHANNEL 1: (is seperate since array indexes in GetData_Double are not as ordered
inphase = mean(GetData_Double(6, settled_count, Timetrace.runtime_counts));
inphase_harm = mean(GetData_Double(5, settled_count, Timetrace.runtime_counts));
quadrature = mean(GetData_Double(13, settled_count, Timetrace.runtime_counts));
quadrature_harm = mean(GetData_Double(14, settled_count, Timetrace.runtime_counts));
R = sqrt(inphase^2 + quadrature^2);
Theta = atan2(quadrature, inphase) * 180 / pi;
R_harm = sqrt(inphase_harm^2 + quadrature_harm^2);
Theta_harm = atan2(quadrature_harm, inphase_harm) * 180 / pi;

output = output + sprintf("Ch %d Inphase: %.5f    %d. Harm: %.5f\n", 1, inphase, harmonic, inphase_harm);
output = output + sprintf("Ch %d Quadrature: %.5f    %d. Harm: %.5f\n", 1, quadrature, harmonic, quadrature_harm);
output = output + sprintf("R: %.5f           %d. Harm: %.5f\n", R, harmonic, R_harm);
output = output + sprintf("Theta (deg): %.2f     %d. Harm: %.2f\n\n", Theta, harmonic, Theta_harm);

for ch = 2:8
    offset = (ch-2)*8;
    inphase = mean(GetData_Double(20+offset, settled_count, Timetrace.runtime_counts));
    inphase_harm = mean(GetData_Double(24+offset, settled_count, Timetrace.runtime_counts));
    quadrature = mean(GetData_Double(21+offset, settled_count, Timetrace.runtime_counts));
    quadrature_harm = mean(GetData_Double(25+offset, settled_count, Timetrace.runtime_counts));
    
    R = sqrt(inphase^2 + quadrature^2);
    Theta = atan2(quadrature, inphase) * 180 / pi;
    R_harm = sqrt(inphase_harm^2 + quadrature_harm^2);
    Theta_harm = atan2(quadrature_harm, inphase_harm) * 180 / pi;
    
    output = output + sprintf("Ch %d Inphase: %.5f    %d. Harm: %.5f\n", ch, inphase, harmonic, inphase_harm);
    output = output + sprintf("Ch %d Quadrature: %.5f    %d. Harm: %.5f\n", ch, quadrature, harmonic, quadrature_harm);
    output = output + sprintf("R: %.5f           %d. Harm: %.5f\n", R, harmonic, R_harm);
    output = output + sprintf("Theta (deg): %.2f     %d. Harm: %.2f\n\n", Theta, harmonic, Theta_harm);
end

uicontrol('Style', 'edit', 'Max', 10, 'Min', 1, 'String', output, 'Position', [10, 10, 580, 680], ...
    'BackgroundColor', 'black', 'ForegroundColor', 'white', 'FontName', 'Consolas', 'FontSize', 11, 'HorizontalAlignment', 'left');



%prints the values in a window:
