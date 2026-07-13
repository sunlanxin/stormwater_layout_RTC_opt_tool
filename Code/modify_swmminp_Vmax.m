function newinp = modify_swmminp_Vmax(input, As)
%This function modifies the bottom area of the storage basin in the [STORAGE] module, As
%input is the swmm.inp file to be modified
path = pwd;
Surfarea = As;
%% Open the original .inp file and extract the modules that need to update their parameters
oldinp=fopen(input,'rt+');
STORAGE=fopen('STORAGE.txt','wt+');% the [STORAGE] module in SWMM .inp to be modified

%if oldinp ~= -1
%    disp('File opened successfully！');
%end
i=0;
k=0;
while ~feof(oldinp)
    tline=fgetl(oldinp);
    if tline==-1
        break;
    end
    %disp(tline)
    i=i+1;
    if contains(tline,'[STORAGE]')
        k=1;
    elseif contains(tline,'[CONDUITS]')
        k=0;
    end
    
    if k
        fprintf(STORAGE,'%s\n',tline);
    end
end
fclose(oldinp);
fclose(STORAGE);

%% CURVE-STORAGE
%--------------------------------------------------------
STORAGE=fopen('STORAGE.txt','rt+');
si=0;
while ~feof(STORAGE)
    tline=fgetl(STORAGE);
    if tline==-1
        break;
    else
        si=si+1;
    end
end
frewind(STORAGE)
lines= textscan(STORAGE,'%s %s %s %s %s %s %s %s %s %s',si-3,'Headerlines',3);
N3=size(lines{1,1},1);
Nrow3=10;

% Modification of storage tank's surface area
if N3~=0
    for k=1:Nrow3
        if k==8
            for kk=1:N3
                SV{kk,1} = Surfarea(kk);%%%%%%%%%%%%%%%
            end
            lines{1,k}=SV;
        end
    end
    
    celllines=cell(1,Nrow3);
    for i = 1:Nrow3
        for j = 1:N3
            a=(lines{1,i}(j,1));
            celllines(j,i)=a;
        end
    end
    
    up_ST = fopen('celllines.txt','w');
    format1 = '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%f\t%s\t%s\n';
    [nrows,ncols] = size(celllines);
    for row = 1:nrows
        fprintf(up_ST,format1,celllines{row,:});
    end
    fclose(up_ST);
    
    up_ST = fopen('celllines.txt','r');
    frewind(STORAGE)
    si=0;
    while ~feof(STORAGE)&&~feof(up_ST)
        tline=fgetl(STORAGE);
        si=si+1;
        newline{si} = tline;
        if si>3 %
            newData=fgetl(up_ST);
            newline{si} = strrep(tline,tline,newData);
        end
    end
    fclose(up_ST);
    fclose(STORAGE);
    
    STORAGE=fopen('STORAGE.txt','wt+');
    for k=1:si
        fprintf(STORAGE,'%s\n',newline{k});
    end
end
%--------------------------------------------------------
frewind(STORAGE)

%% Generate a new .inp with each module after changing the parameters.
oldinp=fopen(input,'rt+');
%if oldinp ~= -1
    %disp('File opened successfully！');
%end
i=0;
k=0;
while ~feof(oldinp)
    tline=fgetl(oldinp);
    i=i+1;
    if tline==-1
        break
    else
        newline{i} = tline;
    end
    %disp(tline)
    if contains(tline,'[STORAGE]')
        k=1;
    elseif contains(tline,'[CONDUITS]')
        k=0;
    end
    
    if k&&~feof(STORAGE)
        newData=fgetl(STORAGE);
        newline{i} = strrep(tline,tline,newData);
    end
end
newinp = strrep(input,'.inp',strcat('_Vopt.inp'));
newinp2 = fopen(newinp,'wt+');
for k=1:i-1
    fprintf(newinp2,'%s\n',newline{k});
end
clear lines;
fclose all;
delete("celllines.txt");
delete("STORAGE.txt");
end