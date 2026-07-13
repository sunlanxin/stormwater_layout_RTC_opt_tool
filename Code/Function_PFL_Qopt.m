function [Qoutlet, Hmax] = Function_PFL_Qopt(QT_event, input, NamePara, TankPara, ControlPara)
% 本代码为降雨期间PFL_RBC目标流量控制模拟，以深圳光明区排水分区7-2为例
% 控制目标：水量目标（洪峰削减率、径流削减率）
% 系统模型：TVGM-Urban城市产汇流模型+SWMM模型（模拟）
% 控制模型：基于降雨预报的规则控制算法（PFL-RBC），动态生成系统总出口处的目标流量并分配给上游调蓄节点
TANKS = NamePara.TANKS;
INLET = NamePara.INLET;
OVERF = NamePara.OVERF;
INJUNC = NamePara.INJUNC;
OUTJUNC = NamePara.OUTJUNC;
PUMP1 = NamePara.PUMP1;
PUMP2 = NamePara.PUMP2;
Number = size(TANKS, 2); %调蓄点数量
%【%%%%%%%%变量定义】
h = []; %调蓄池水位
QIN = []; %调蓄池入流量（进口闸控制）
QOUT = []; %调蓄池出流量（水泵控制）
Qsys = []; %总出口流量
QOVER = [];%溢流量
QUSE = [];%回用流量
constep = ControlPara(1).constep;
% constep, 控制步长，min
dt = constep;%时间步长,min
Qmin = 0.1;%雨天判断：最小流量阈值，L/s
%% 实时控制模拟
%plan = 1;
opt = 1; % 优化算法，1-GA，2-NSGA

% 初始边界
td = 0;
h(1, 1) = TankPara(1).Hmin;
QIN(1, 1) = 0;
QOUT(1, 1) = 0;
Qsys(1, 1) = 0;
QOVER(1, 1) = 0;
QUSE(1, 1) = 0;
Hp(1, 1:Number) = 0;
valve(1, 1:Number) = 0;
pump1(1, 1:Number) = 0;
pump2(1, 1:Number) = 0;
Avalve(1) = valve(1, 1);
Apump1(1) = pump1(1, 1);
Apump2(1) = pump2(1, 1);
%Qtarget(1, 1:Number) = 0;

% 模拟开始s
swmm = SWMM;
swmm.initialize(input);% 初始化系统物理模型

ts = 1;
tc = 1;

k = 0;
while (~swmm.is_over)
    k = k + 1;
    tnow(k,1) = swmm.run_step * 60; % min
    if fix(tnow(k,1)) / dt == ts %模拟步长
        % 读取当前系统状态值，在实际应用中，这些数据通过系统实时监测获取
        for m = 1 : Number
            H1(ts, m) = swmm.get(convertStringsToChars(INJUNC(m)), swmm.DEPTH, swmm.SI); % 闸前水位, m
            Qrunoff(ts, m) = swmm.get(convertStringsToChars(INJUNC(m)), swmm.INFLOW, swmm.SI) * 1000; % 系统入口流量, L/s;
            h(ts, m) = swmm.get(convertStringsToChars(TANKS(m)), swmm.DEPTH, swmm.SI); % 池内水位, m
            QIN(ts, m) = swmm.get(convertStringsToChars(INLET(m)), swmm.FLOW, swmm.SI) * 1000; % 入池流量, L/s
            QOVER(ts, m) = swmm.get(convertStringsToChars(OVERF(m)), swmm.FLOW, swmm.SI) * 1000; % 溢流量, L/s
            QOUT(ts, m) = swmm.get(convertStringsToChars(PUMP1(m)), swmm.FLOW, swmm.SI) * 1000; % 排水流量, L/s
            QUSE(ts, m) = swmm.get(convertStringsToChars(PUMP2(m)), swmm.FLOW, swmm.SI) * 1000; % 回用流量,L/s
            Qsys(ts, m) = swmm.get(convertStringsToChars(OUTJUNC(m)), swmm.INFLOW, swmm.SI) * 1000; % 系统出口流量, L/s
        end
        
        % 判断当前时段是否为控制时段
        if fix(tnow(k,1)) / constep == tc %控制步长
            % 保存系统状态值、控制点
            for m = 1 : Number
                % 保存系统状态值、控制点
                StatePara(m) = struct('Qrunoff', Qrunoff(ts, m), 'H1', H1(ts, m), 'h', h(ts, m), 'Qin', QIN(ts, m), 'Qout', QOUT(ts, m), 'Qover', QOVER(ts, m), 'Quse', QUSE(ts, m), 'Q', Qsys(ts, m));
                SetpointPara(m) = struct('Avalve', valve(ts, m), 'Apump1', pump1(ts, m), 'Apump2', pump2(ts, m));
                
                ControlPara(m).Qmax = QT_event(m, 1);
                
                [Avalve(m), Apump1(m), Apump2(m)] = control_model_wet_QTopt(StatePara(m), TankPara(m), ControlPara(m), SetpointPara(m));
                if TankPara(m).As == 0
                    Avalve(m) = 0;
                end
                %fprintf("第%d个控制时段第%d个调蓄点的决策结果为:%f,%f,%f\n", tc, m, Avalve(m), Apump1(m), Apump2(m));
                
                % 修改控制点setting
                swmm.modify_setting(convertStringsToChars(INLET(m)), Avalve(m));%调蓄池进水闸，远程控制
                swmm.modify_setting(convertStringsToChars(PUMP1(m)), Apump1(m));%排空泵，远程控制
                swmm.modify_setting(convertStringsToChars(PUMP2(m)), Apump2(m));%回用泵，远程控制
            end
            % 控制时段长+1
            tc = tc + 1;
        end
        
        % 更新模拟时段的控制点setting
        for m = 1 : Number
            swmm.modify_setting(convertStringsToChars(INLET(m)), Avalve(m));%调蓄池进水闸，远程控制
            swmm.modify_setting(convertStringsToChars(PUMP1(m)), Apump1(m));%排空泵，远程控制
            swmm.modify_setting(convertStringsToChars(PUMP2(m)), Apump2(m));%回用泵，远程控制
            valve(ts+1, m) = Avalve(m);
            pump1(ts+1, m) = Apump1(m);
            pump2(ts+1, m) = Apump2(m);
            
            % 假设闸门状态变化可在瞬间完成，修改本时段出流量
            Qin_new(ts, m) = min(Function_valve_to_flow(H1(ts, m), TankPara(m).d, TankPara(m).Z0, valve(ts+1, m), TankPara(m).Cd), Qrunoff(ts, m));
            
            % 状态值修正：超出总入流-入池流量的溢流、超出总入流-入池流量+溢流量+排水量的从总出流量
            QOVER(ts, m) = max(QOVER(ts, m),0);
            Qsys(ts, m) = min(Qrunoff(ts, m)+QOUT(ts, m)+QOVER(ts, m), Qsys(ts, m)); % 模型结果
            Qsys_new0(ts, m) = Qrunoff(ts, m)+QOUT(ts, m)+QOVER(ts, m)-Qin_new(ts, m); % 理论结果
            Qsys_new(ts, m) = min(Qsys(ts, m),Qsys_new0(ts, m));% 取两者中的最小值
        end
        % 模拟时段长+1
        ts = ts + 1;
    end
end
Qsys_new(Qsys_new < Qmin) = 0;
[errors,duration] = swmm.finish;
%flooding = swmm.total_flooding/1000; %溢流量，m3

Qoutlet = Qsys_new(:,1);
Hmax = max(h);
% 读取适应度函数状态变量
%for m = 1 : Number
%    V(:, m) = h(:, m)* TankPara(m).As;
%end
end

function [Av, Ap1, Ap2] = control_model_wet_QTopt(StatePara, TankPara, ControlPara, SetpointPara)
% 本函数用于生成雨天的控制策略
% 输入：系统实时监测状态、系统物理属性、降雨预报数据
% 输出：本时段控制点决策值，setting for orifices and pumps
% plan 1: 规则控制（蓄水）
% plan 2: 多目标规则控制（大雨削峰、小雨蓄雨）
% plan 3: 以削峰为主的模型预测控制

% 当前系统状态
Qrunoff = StatePara.Qrunoff; % 上游来水量
H1 = StatePara.H1; % 闸门上游水深
h = StatePara.h; % 调蓄池水深
Qin = StatePara.Qin; % 调蓄池入流量
Qout = StatePara.Qout; % 调蓄池出流量
Qover = StatePara.Qover; % 调蓄池溢流量
Quse = StatePara.Quse; % 回用水量
Q = StatePara.Q; % 总出口流量
Avalve = SetpointPara.Avalve; % 闸门初始状态
Apump1 = SetpointPara.Apump1; % 水泵1初始状态
Apump2 = SetpointPara.Apump2; % 水泵1初始状态
Cd = TankPara.Cd; %闸门过流系数

% 调蓄池参数
Hmin = TankPara.Hmin; % 闸门初始状态
Hmax = TankPara.Hmax;
As = TankPara.As;
d = TankPara.d;
Z0 = TankPara.Z0;

% 控制参数
constep = ControlPara.constep;
Qmax = ControlPara.Qmax;

if h < Hmax
    if Qrunoff >= Qmax
        Qin_new = Qrunoff - Qmax;
        Av = Function_flow_to_valve(H1, d, Z0, Qin_new, Cd);
        if Qin_new == Qrunoff
            Av = 1;
        end
    else
        Av = 0;
    end
else
    Av = 0;
end


Ap1 = 0;
Ap2 = 0;

end

function Qin_new = Function_valve_to_flow(H1, d, Z0, Av, Cd)
%%
%H1 = 0.3005;
%d = 0.3;
%Av = 1;
%Z0 = 0.2;
%Cd = 0.65;
g = 9.81;
enta = (H1 - Z0) / d;

if enta > 0
    x0 = Av;
    A0 = d^2 / 4 * (acos(1 - 2*x0) - (1 - 2*x0) .* sin(acos(1 - 2*x0)));
    
    if x0  <  enta
        He = H1 - Z0 - d / 2 * x0;
        y0 = Cd * A0 * (2 * 9.81 * He)^0.5 * 1000;
    else
        y0 = Cd * (H1 - Z0)^1.5 * g^0.5 * A0/ (x0 * d) * 1000;
    end
else
    y0 = 0;
end

% getenv('BLAS_VERSION')
% setenv('BLAS_VERSION','')

Qin_new = y0;
end

function Avalve = Function_flow_to_valve(H1, d, Z0, Qin_new, Cd)
%%
%H1 = 0.3187;
%d = 0.3;
%Qin_new = Qrunoff(2233)-2.5;
%Z0 = 0.2;
%Cd = 5;
g = 9.81;
enta = min(round((H1 - Z0) / d,2),1);

if enta > 0
    x01 = 0:1/200:enta;
    N1 = size(x01, 2);
    A01 = d^2 / 4 * (acos(1 - 2*x01) - (1 - 2*x01) .* sin(acos(1 - 2*x01)));
    He = H1 - Z0 - d / 2 * x01;
    y01(1) = 0;
    y01(2:N1) = Cd * A01(2:N1) .* (2 * 9.81 * He(2:N1)).^0.5 * 1000;
    % yi1 = Qin_new;
    delta1 = abs(y01-Qin_new);
    id = find(delta1 == min(delta1), 1, 'first');
    x1 = x01(id);
    
    % getenv('BLAS_VERSION')
    % setenv('BLAS_VERSION','')
    
    x02 = enta:1/200:1;
    A02 = d^2 / 4 * (acos(1 - 2*x02) - (1 - 2*x02) .* sin(acos(1 - 2*x02)));
    y02 = Cd * (H1 - Z0)^1.5 * g^0.5 * A02 ./ (x02 * d) * 1000;
    delta2 = abs(y02-Qin_new);
    id = find(delta2 == min(delta2), 1, 'last');
    x2 = x02(id);
    
    
    if min(delta1) <= min(delta2)
        Avalve = x1;
    else
        Avalve = x2;
    end
    
else
    Avalve = 1;
end

end