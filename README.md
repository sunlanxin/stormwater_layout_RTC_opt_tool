# stormwater_layout_RTC_opt_tool

The `stormwater_layout_RTC_opt_tool` provides synergistic optimization tools for practitioners to design stormwater storage systems under the premise of real-time control (RTC).

This tool can generate combined solutions of layout designs (i.e. storage capacity allocation) and control settings (i.e. target flow distribution) for distributed storage tanks.


## Code

The main modules were coded in MATLAB, as listed below:

1. `Main_pi_Vmax_opt.m` to acquire input data and drive the optimization procedure

2. `nsga_2.m` to solve the optimziaiton problem with objectives of minimizing system flood peaks and runoff volume

3. `modify_swmminp_timeseries_temp.m`  to update the input file with the simulated rainfall events

4. `modify_swmminp_Vmax.m`  to update the input file with different layout schemes during the optimzation procedure

5. `Function_peakpredict_flc.m` to generate the basic RTC parameter (i.e. target flow) under differnt rainfall events

6. `Function_PFL_Qopt.m` to execute the dynamic operations with different RTC strategied during the optimzation procedure. 


Noted that:

- `TVGM-SWMM` (https://github.com/jiangziyin/TVGM-SWMM)  was used as the stormwater system model, while researchers can choose other models such as the original SWMM.

-  `MatSWMM` (developed by Riano-Briceno et al. in 2016) was used to run the stormwater system model.


## Data

-  the simulated rainfall input of a case

-  the .inp file of SWMM


## Running steps

1. download the `MatSWMM` software and copy the packages and files to `\stormwater_layout_RTC_opt_tool\Code` 

2. prepare a SWMM input file and copy it to `\stormwater_layout_RTC_opt_tool\Data`

2. prepare the simulated rainfall events data and copy it to `\stormwater_layout_RTC_opt_tool\Data`

3. run the `Main_pi_Vmax_opt.m.m` and output the optimization outcomes
