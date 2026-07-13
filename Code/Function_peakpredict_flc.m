function Qmax = Function_peakpredict_flc(PP24, Vmax, TankPara, Hp, h)
% This function calculates the flood peak threshold in the target flow control strategy.
a2 = readfis('target flow-opt');
Number = size(Hp, 2);
q = 0;
for m =1:Number
    Hmin(m) = TankPara(m).Hmin;
    h(m) = max(h(m), Hmin(m));
    if Hp(m) >= h(m) + 0.0001 && TankPara(m).As
        q = 1;
    end
end

if q
    Qmax = 0;
else
    Qmax = evalfis(a2, [PP24, Vmax]);
end
end