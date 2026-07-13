function newinp = modify_swmminp_timeseries_temp(input, inp_Precip, e)
%This function writes precipitation data as a timeseries sequence to an INP file and modifies START_DATE, START_TIME, REPORT_START_DATE, REPORT_START_TIME, END_DATE, and END_TIME.
%However, it does not save the original timeseries, as it is intended for parameter calibration on a per-run basis.
%inp_Precip is the rainfall sequence information in inp format, e.g., “[‘calib’,”2021/6/23“,”14:15“,”0.2“]”
%input is the swmm.inp file to be modified;

add = inp_Precip; %Information on rainfall events to be added in the INP file
START_DATE = inp_Precip(1,2);
START_TIME = inp_Precip(1,3);
REPORT_START_DATE = inp_Precip(1,2);
REPORT_START_TIME = inp_Precip(1,3);
END_DATE = inp_Precip(end,2);
END_TIME = inp_Precip(end,3);
oldinp = fopen(input,'rt+');% Files to be read
timeseries = fopen('timeseries.txt','wt+');

Title = ["[TIMESERIES]", ";;Name	Date	Time	Value", ";;-------------- ------------------ ------------------"];
fprintf(timeseries,'%s\n',Title);    

% Preserve the original information of [TIMESERIES]
%i = 0;
%k1 = 0;
%while ~feof(oldinp)
%    tline= fgetl(oldinp);
%    if tline == -1
%        break;
%    end
%    disp(tline)
%    i=i+1;
%    if contains(tline,'[TIMESERIES]')
%        k1 = 1;
%        
%    elseif contains(tline,'[REPORT]')
%        k1 = 0;
%    end
%    
%    if k1 && tline~=""
%        fprintf(timeseries,'%s\n',tline);
%    end
%end
%fprintf(timeseries,'%s\n',';');

for i = 1 : size(add, 1) %Append the sequence to the end of the timeseries.
    tline = strjoin(add(i,:),'\t');
    fprintf(timeseries,'%s\n',tline);
end
fprintf(timeseries,'%s\n',' ');

%Place the modified timeseries back into the inp file to generate a newinp.
frewind(oldinp)
frewind(timeseries)
i = 0;
k1 = 0;
while ~feof(oldinp)
    tline = fgetl(oldinp);
    i = i+1;
    if tline == -1
        break
    elseif contains(tline,'[TIMESERIES]')
        k1 = 1;
        while ~feof(timeseries)
            newData = fgetl(timeseries);
            if newData == -1
                break
            else
                newline{i} = newData;
            end
            i=i+1;
        end
    elseif contains(tline,'[REPORT]')
        k1 = 0;
    end
    
    if k1
        i = i-1;
    else
        if contains(tline,'START_DATE') && ~contains(tline,'REPORT')
            newline{i} = convertStringsToChars(strcat("START_DATE","             ",START_DATE));
        elseif contains(tline,'START_TIME') && ~contains(tline,'REPORT')
            newline{i} = convertStringsToChars(strcat("START_TIME","             ",START_TIME));
        elseif contains(tline,'REPORT_START_DATE')
            newline{i} = convertStringsToChars(strcat("REPORT_START_DATE","             ",REPORT_START_DATE));
        elseif contains(tline,'REPORT_START_TIME')
            newline{i} = convertStringsToChars(strcat("REPORT_START_TIME","             ",REPORT_START_TIME));
        elseif contains(tline,'END_DATE')
            newline{i} = convertStringsToChars(strcat("END_DATE","             ",END_DATE));
        elseif contains(tline,'END_TIME')
            newline{i} = convertStringsToChars(strcat("END_TIME","             ",END_TIME));
        else
            newline{i} = tline;
        end
    end
    %disp(tline)
end
fclose(oldinp);
  
randstr = string(rand());
newinp = strrep(input,'.inp',strcat('_',string(e),'.inp'));
newinp2 = fopen(newinp,'wt+');
for k = 1:i-1
    fprintf(newinp2,'%s\n',newline{k});
end
fclose(newinp2);
fclose all;
delete("timeseries.txt");
end