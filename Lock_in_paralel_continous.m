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
Timetrace.scanrate = 300000;       % Hz
Timetrace.points_av = 60;        % points to average
Timetrace.process_number = 2;        
Timetrace.model ='ADwin';
Timetrace.process = 'Read_AI_fast_multi_continous';


%% Initialize
Settings = Init(Settings);

%% Initialize ADwin
Settings = Init_ADwin(Settings, Timetrace);

%% set up sinewave
f_wanted = 23;
phi_shift = 0; %phase shift in degrees
RMS = 1; %RMS value of excitation voltage

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
Set_Processdelay(2, Timetrace.process_delay);

% set ADCs
Set_Par(10, Settings.input_resolution);

% set addresses
Set_Par(5,Settings.AI_address);
Set_Par(7,Settings.DIO_address);

% set amplifier settings
IV_gains = [0, 0, 0, 0, 0, 0, 0, 0]; %it will be calculated as 10^(-gain)
SetData_Double(15, IV_gains, 0);

% set averaging
Set_Par(21, Timetrace.points_av);

%% set ADC gains
SetData_Double(11, Settings.ADC_gain, 0);

%% set up filtering and mixing

% set realtime filering parameters
cutoff = 0.5;
order = 4;
[b, a] = butter(order,  cutoff / (Timetrace.sampling_rate / 2), 'low');
SetData_Double(3, [b, a], 0); % set filter parameters

% set up references
harmonic = 2;
q = 1:2*wave_vec_length; % 2*length to extend it for 90degree offset
q = q -Timetrace.points_av/(2*repeats) + 0.5 -1; % q - (fvsett/fvmeasure - 1)/2, subtracts shift of uneven setting/reading
%the additional -1 stems from the fact that voltage setting happens before mixing: implemented this way because then ADC can work during rest of code
internal_reference_wave =  sqrt(2) * cos(q*2*pi/wave_vec_length);
internal_reference_wave_harm =  sqrt(2) * cos(harmonic*q*2*pi/wave_vec_length);

% passes references to ADwin
SetData_Double(4, internal_reference_wave, 0);
SetData_Double(8, internal_reference_wave_harm, 0);
Set_Par(28, round(wave_vec_length/4)); % quarter wavelength (90degree shift)
Set_Par(31, round(wave_vec_length/(4*harmonic))); % harmonic quarter wavelength (90degree shift)

%% run measurement
Start_Process(2);

%% ADWIN readout and visualization

% Create UI figure
fig = uifigure('Name', ['Channel:', ' x'], 'Position', [100, 100, 600, 700]);

% Preallocate label arrays
labels = gobjects(8, 4); % 4 parameters: I, Q, R, Theta

% Create labels
for i = 1:8
    y_offset = 650 - (i-1)*80; % spacing between channel blocks
    labels(i, 1) = uilabel(fig, 'Position', [20, y_offset, 560, 20], 'Text', sprintf('Ch %d Inphase: ', i));
    labels(i, 2) = uilabel(fig, 'Position', [20, y_offset - 20, 560, 20], 'Text', sprintf('Ch %d Quadrature: ', i));
    labels(i, 3) = uilabel(fig, 'Position', [20, y_offset - 40, 560, 20], 'Text', sprintf('Ch %d R: ', i));
    labels(i, 4) = uilabel(fig, 'Position', [300, y_offset - 40, 560, 20], 'Text', sprintf('Ch %d Theta (deg): ', i));
end

% continously reads from ADwin
while isvalid(fig)
    idx = Get_Par(19);

    % if PAR_19 is read directly bewteen updates this can lead to mistakes: this corrects some of it
    if idx == 5
        idx = 4;
    end

    %CHANNEL 1: is seperate due to unordered array numbering
    % Get main signals
    I = GetData_Double(6, idx, 1);
    Q = GetData_Double(5, idx, 1);
    R = sqrt(I.^2 + Q.^2);
    Theta = atan2(Q, I) * 180 / pi;

    % Get harmonic signals
    I_harm = GetData_Double(13, idx, 1);
    Q_harm = GetData_Double(14, idx, 1);
    R_harm = sqrt(I_harm.^2 + Q_harm.^2);
    Theta_harm = atan2(Q_harm, I_harm) * 180 / pi;

    % Update labels
    labels(1,1).Text = sprintf('Ch %d Inphase: %.5f    %d. Harm: %.5f', 1, I, harmonic, I_harm);
    labels(1,2).Text = sprintf('Ch %d Quadrature: %.5f %d. Harm: %.5f', 1, Q, harmonic, Q_harm);
    labels(1,3).Text = sprintf('R: %.5f                   %d. Harm: %.5f', R, harmonic, R_harm);
    labels(1,4).Text = sprintf('Theta (deg): %.2f         %d. Harm: %.2f', Theta, harmonic, Theta_harm);

    %reads remaining channels:
    for i = 2:8
        % Base channel index offset
        base = (i - 2) * 8;

        % Get main signals
        I = GetData_Double(20 + base, idx, 1);
        Q = GetData_Double(21 + base, idx, 1);
        R = sqrt(I.^2 + Q.^2);
        Theta = atan2(Q, I) * 180 / pi;

        % Get harmonic signals
        I_harm = GetData_Double(24 + base, idx, 1);
        Q_harm = GetData_Double(25 + base, idx, 1);
        R_harm = sqrt(I_harm.^2 + Q_harm.^2);
        Theta_harm = atan2(Q_harm, I_harm) * 180 / pi;

        % Update labels
        labels(i,1).Text = sprintf('Ch %d Inphase: %.5f    %d. Harm: %.5f', i, I, harmonic, I_harm);
        labels(i,2).Text = sprintf('Ch %d Quadrature: %.5f %d. Harm: %.5f', i, Q, harmonic, Q_harm);
        labels(i,3).Text = sprintf('R: %.5f                   %d. Harm: %.5f', R, harmonic, R_harm);
        labels(i,4).Text = sprintf('Theta (deg): %.2f         %d. Harm: %.2f', Theta, harmonic, Theta_harm);
    end
    
    % controlled pause for smoother output
    pause(0.1);
end