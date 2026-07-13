clc;clear all;
%% STATEMENT
% This code is the main functions for the synergistic optimization of spatial layout and target flow allocation in distributed stormwater storage systems.
% Optimization Objectives: Minimum Peak Flow, Minimum Runoff
% Optimization Algorithm: NSGA-II

PATH = "C:\Users\ss\Desktop\stormwater_layout_RTC_opt_tool\Data";
IMP = 28.92215; %impervious surface area，ha
VM = 500; %storage capacity，m3/ha
input = strcat(PATH,"\swmm_files\inpFile-VQTopt-V=500.inp"); %path of .inp file for running SWMM model

%% Training Dataset - 16 Rainfall Events
load(strcat(PATH,"\4-DS.mat"))
load(strcat(PATH,"\7-2019~2020.mat"))
load(strcat(PATH,"\5-2021~2022.mat"))

% designed rainfall events in 4-DS.mat
P_event{1,1} = Pds{4, 6}; time_event{1,1} = timeds{4, 6}; 
P_event{2,1} = Pds{4, 10}; time_event{2,1} = timeds{4, 10}; 
P_event{3,1} = Pds{9, 6}; time_event{3,1} = timeds{9, 6};
P_event{4,1} = Pds{9, 10}; time_event{4,1} = timeds{9, 10};

% designed rainfall events in 5-2021~2022.mat
P_event(5:11,1) = Event_P1(1:7, 1); time_event(5:11,1) = Event_time1(1:7, 1);

% designed rainfall events in 7-2019~2020.mat
P_event(12:16,1) = Event_P2(1:5, 1); time_event(12:16,1) = Event_time2(1:5, 1); 

% simulated baseline peak flow
Qm0_event(1:4, 1) = [inpeakds(4, 6);inpeakds(4, 10);inpeakds(9, 6);inpeakds(9, 10)];
Qm0_event(5:11, 1) = Event_inpeak1;
Qm0_event(12:16, 1) = Event_inpeak2;

Nevent = size(P_event, 1);
for e = 1 : Nevent
    N = size(P_event{e, 1},1);
    Ptotal(e, 1) = sum(P_event{e, 1});
    name0(1:N,1) = "QTopt_event";
    name_event{e,1} = name0;
    clear name0;
end

%% INP file update
% Write rainfall input into the INP file
for e = 1 : Nevent
    P = P_event{e, 1};
    time = time_event{e, 1};
    name = name_event{e, 1};
    inp_Precip = [name, time, P];
    %clear name;
    newinp(e) = modify_swmminp_timeseries_temp(input, inp_Precip, e); 
end

%% Parameter setting
%Inititalizaiton of system parameters of distributed storage tanks
TANKS = ["T1-1","T2-1","T2-2","T3-1","T3-2","T3-3","T3-4","T3-5","T4-1","T4-2","T4-3","T4-4","T4-5"];
INLET = ["Inlet1-1","Inlet2-1","Inlet2-2","Inlet3-1","Inlet3-2","Inlet3-3","Inlet3-4","Inlet3-5","Inlet4-1","Inlet4-2","Inlet4-3","Inlet4-4","Inlet4-5"];
OVERF = ["Overflow1-1","Overflow2-1","Overflow2-2","Overflow3-1","Overflow3-2","Overflow3-3","Overflow3-4","Overflow3-5","Overflow4-1","Overflow4-2","Overflow4-3","Overflow4-4","Overflow4-5"];
INJUNC = ["AJ1-1-0","AJ2-1-0","AJ2-2-0","AJ3-1-0","AJ3-2-0","AJ3-3-0","AJ3-4-0","AJ3-5-0","AJ4-1-0","AJ4-2-0","AJ4-3-0","AJ4-4-0","AJ4-5-0"];
OUTJUNC = ["7-2","AJ2-1-2","AJ2-2-2","AJ3-1-2","AJ3-2-2","AJ3-3-2","AJ3-4-2","AJ3-5-2","AJ4-1-2","AJ4-2-2","AJ4-3-2","AJ4-4-2","AJ4-5-2"];
PUMP1 = ["Pdry1-1","Pdry2-1","Pdry2-2","Pdry3-1","Pdry3-2","Pdry3-3","Pdry3-4","Pdry3-5","Pdry4-1","Pdry4-2","Pdry4-3","Pdry4-4","Pdry4-5"];
PUMP2 = ["Puse1-1","Puse2-1","Puse2-2","Puse3-1","Puse3-2","Puse3-3","Puse3-4","Puse3-5","Puse4-1","Puse4-2","Puse4-3","Puse4-4","Puse4-5"];
NamePara = struct('TANKS', TANKS, 'INLET', INLET, 'OVERF', OVERF, 'INJUNC', INJUNC, 'OUTJUNC', OUTJUNC, 'PUMP1', PUMP1, 'PUMP2', PUMP2); 
area  = [85.29091064, 75.22773296, 9.408757766, 26.04045414, 6.136559966, 31.84895189, 3.014158894, 5.332729203, 5.80225741, 8.704821561, 7.480571601, 2.618034956, 1.980037769] * 10000;%调蓄点上游汇水面积

%Inititalizaiton of layout parameters(storage capacity distribution ratio-pV)
pV0 = [0.317201035, 0.279775589, 0.034991627, 0.096845712, 0.022822164, 0.118447797, 0.011209803, 0.019832679, 0.021578877, 0.032373654, 0.027820609, 0.009736599, 0.007363857];
As = VM*IMP*pV0/3;
Cd = 0.65;
Number = size(TANKS, 2);
for m = 1 : Number
    TankPara(m) = struct('Hmin', 0, 'Hmax', 3, 'As', As(m), 'd', 0.8, 'Z0', 0.2, 'A', area(m),'Cd', Cd, 'Vtotal', VM*IMP);
    Vmax(m) = fix(TankPara(m).As * (TankPara(m).Hmax - TankPara(m).Hmin)/IMP);
end
 
% Inititalizaiton of RTC parameters (target flow allocation ratio-pi)
for m = 1 : Number
    ControlPara(m) = struct('constep', 5, 'Qmax', 0);
end
QT_ratio0 = [1, 0.882013481, 0.110313722, 0.305313356, 0.071948581, 0.373415545, 0.035339743, 0.062524004, 0.068029024, 0.102060366, 0.087706551, 0.030695357, 0.023215109];

%% Fuzzy logic control method for target flow calculation
for e = 1 : Nevent
    h = 0;
    Hp = 0;
    Qtarget(e, 1) = Function_peakpredict_flc(sum(P_event{e,1}), VM, TankPara, Hp, h);
    %Qtarget(e, 1) = 0;
end

%% Optimization NSGA-Ⅱ
Nopt = Number-1;
pop = 100; % population size
gen = 50; % number of iterations
M = 2; % numberof objective functions
V = 2*Nopt; % dimension (number of decision variables)
min_range = zeros(1, V); % low boundary
max_range = [ones(1,Nopt).*QT_ratio0(2:end),min(QT_ratio0(2:end)*2,1)]; % upper boundary
init_range = [ones(1,Nopt).*pV0(2:end),QT_ratio0(2:end)]; %initial value

% parallel processing
poolobj = gcp;
addAttachedFiles(poolobj,{convertStringsToChars(PATH)})
t1 = clock;
disp('Optimization in progress!Please wait...');
[x, J, geninform] = nsga_2(pop, gen, M, V, Nopt, init_range, min_range, max_range, newinp, Qtarget, Qm0_event, NamePara, TankPara, ControlPara);

t2 = clock;
t=etime(t2,t1);
disp(['Running time：',num2str(t),'seconds']);

delete(poolobj)
