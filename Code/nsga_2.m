%% NSGA-Ⅱ main function
function [x, J, geninform] = nsga_2(pop, gen, M, V, Nopt, init_range, min_range, max_range, newinp, Qtarget, Qm0_event, NamePara, TankPara, ControlPara)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%This can be modified here
%For more machine learning content, visit omegaxyz.com
%pop = 200; %Population size
%gen = 500; %Number of iterations
%M = 2; %Number of objective functions
%V = 12; %Dimension (number of decision variables)
%min_range = zeros(1, V); % Lower bounds: Generate 1x30 individual vectors, all set to 0
%max_range = ones(1,V); % Upper bounds: Generate 1x30 individual vectors, all set to 1
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
chromosome = initialize_variables(pop, M, V, Nopt, init_range, min_range, max_range, newinp, Qtarget, Qm0_event, NamePara, TankPara, ControlPara);%初始化种群
chromosome = non_domination_sort_mod(chromosome, M, V);% non-dominated quick sort and crowding degree calculation on the initial population.
geninform{1,1} = chromosome; % preserve population information

figure(1)
plot(chromosome(:,V + 1),chromosome(:,V + 2),'*');hold on;

for i = 1 : gen
    pool = round(pop/2);
    tour = 2;
    parent_chromosome = tournament_selection(chromosome, pool, tour);
    mu = 20;
    mum = 20;
    offspring_chromosome = genetic_operator(parent_chromosome, M, V, Nopt, max_range, mu, mum, min_range, max_range, newinp, Qtarget, Qm0_event, NamePara, TankPara, ControlPara);%进行交叉变异产生子代 该代码中使用模拟二进制交叉和多项式变异 采用实数编码
    [main_pop,~] = size(chromosome);
    [offspring_pop,~] = size(offspring_chromosome);
    
    clear temp
    intermediate_chromosome(1:main_pop,:) = chromosome;
    intermediate_chromosome(main_pop + 1 : main_pop + offspring_pop,1 : M+V) = offspring_chromosome;
    intermediate_chromosome = non_domination_sort_mod(intermediate_chromosome, M, V);
    chromosome = replace_chromosome(intermediate_chromosome, M, V, pop);
    %if ~mod(i,5)
    %    clc;
    %    fprintf('%d generations completed\n',i);
    %end
    fprintf('%d generations completed\n',i);
    geninform{i+1,1} = chromosome;
    plot(chromosome(:,V + 1),chromosome(:,V + 2),'*');hold on;
end
hold off;
if M == 1
    id = find(chromosome(:,V + 1) == min(chromosome(:,V + 1)), 1, 'first');
    J = chromosome(id,V + 1);
    x = chromosome(id,1:V);
end

if M == 2
    figure(2)
    plot(chromosome(:,V + 1),chromosome(:,V + 2),'*');
    xlabel('f_1'); ylabel('f_2');
    title('Pareto Optimal Front');
    J = chromosome(:,V + 1:V + 2);
    x = chromosome(:,1:V);
elseif M == 3
    figure(2)
    plot3(chromosome(:,V + 1),chromosome(:,V + 2),chromosome(:,V + 3),'*');
    xlabel('f_1'); ylabel('f_2'); zlabel('f_3');
    title('Pareto Optimal Surface');
    J = chromosome(:,V + 1:V + 3);
    x = chromosome(:,1:V);
end
end

%% Initialization coding
function f = initialize_variables(N, M, V, Nopt, init_range, min_range, max_range, newinp, Qtarget, Qm0_event, NamePara, TankPara, ControlPara)
min = min_range;
max = max_range;
init = init_range;
K = M + V;

for n = 1 : N
    if n == 1
        f(1,:) = init;
    else
        for m = 1 : V
           f(n,m) = min(m) + (max(m) - min(m))*rand(1);
        end
    end
    f(n,V + 1: K) = evaluate_objective(f(n,:), M, V, Nopt, max_range, newinp, Qtarget, Qm0_event, NamePara, TankPara, ControlPara); 
end
end

%% 适应度函数
function F = evaluate_objective(x, M, V, Nopt, max_range, newinp, Qtarget, Qm0_event, NamePara, TankPara, ControlPara)
% This function calculates the fitness function for the  optimization problem
% Optimization Objectives: Minimum Peak Flow, Minimum Runoff

t1 = clock;
Nevent = size(newinp, 2);
f1 = zeros(Nevent,1);
f2 = zeros(Nevent,1);
F = zeros(1,M);

% Variable 1: Storage capacity allocation ratio
S = [1-sum(x(1:Nopt)),x(1:Nopt)]; 
% the cumulative ratio of all upstream tanks that drain to it
Sup = [sum(S),sum(S(1,[2,4:6,9:11])),sum(S(1,[3,7:8,12:13])),sum(S(1,[4,9])),sum(S(5)),sum(S(1,[6,10:11])),sum(S(7)),sum(S(1,[8,12:13])),S(9),S(10),S(11),S(12),S(13)];
Sup_u = [1,max_range(1:Nopt)];

% For storage points exceeding the maximum volume-to-area ratio, reduce proportionally from upstream to downstream.
for m = Nopt+1 : -1: 2
    if Sup(m) > Sup_u(m)
        S(m) = S(m) * Sup_u(m) / Sup(m);
        Sup = [sum(S),sum(S(1,[2,4:6,9:11])),sum(S(1,[3,7:8,12:13])),sum(S(1,[4,9])),sum(S(5)),sum(S(1,[6,10:11])),sum(S(7)),sum(S(1,[8,12:13])),S(9),S(10),S(11),S(12),S(13)];
    end
end
S(1) = 1-sum(S(2:Nopt+1));
if S(1)<0
    m = find(S>S(1)*(-1), 1);
    S(m) = S(m) + S(1);
    S(1) = 0;
end

for m = 1 : Nopt+1
    Vmax(m) = S(m) * TankPara(m).Vtotal;
    As(m) = Vmax(m) / (TankPara(m).Hmax - TankPara(m).Hmin);
    TankPara(m).Vmax = Vmax(m);
    TankPara(m).As = As(m);
end

% Variable 2: Target flow distribution ratio
p = [1,x(Nopt+1:V)];

% Modify the storage  parameters in the INP file - bottom area
for e = 1 : Nevent 
    newinp2(e) = modify_swmminp_Vmax(newinp(e), As);
end

% Run the RTC model
parfor e = 1 : Nevent
    QT_event = Qtarget(e,1) * p'; % Target flow rates for each storage node
    [Q,Hmax] = Function_PFL_Qopt(QT_event, convertStringsToChars(newinp2(e)), NamePara, TankPara, ControlPara);
    temp1 = string(strrep(newinp2(e),'.inp','.out'));
    temp2 = string(strrep(newinp2(e),'.inp','.rpt'));
    temp3 = string(newinp2(e));
    delete(temp1);delete(temp2);delete(temp3);

    % Fitness function calculation
    f1(e, 1) = max(Q)/Qm0_event(e, 1);
    Rv = (TankPara(1).Hmax - min(Hmax,TankPara(1).Hmax))/(TankPara(1).Hmax-TankPara(1).Hmin);
    f2(e, 1) = sum(Rv)/size(TankPara, 2);   
end
F(1) = sum(f1)/Nevent;
F(2) = sum(f2)/Nevent;
t2 = clock;
t=etime(t2,t1);
disp(['Running time：',num2str(t),'seconds']);
end

%% Fast Non-Dominant Sorting and Crowding Degree Calculation Code
%% Initial Population Sorting with Fast Non-Dominant Sorting
% Sort the population using non-dominance ordering. This function returns a two-column matrix containing each individual's ranking value and crowding distance.
% Add the ranking values and crowding distances to the chromosome matrix.
function f = non_domination_sort_mod(x, M, V)
[N, ~] = size(x);
clear m
front = 1;
F(front).f = [];
individual = [];

for i = 1 : N
    individual(i).n = 0;
    individual(i).p = [];
    for j = 1 : N
        dom_less = 0;
        dom_equal = 0;
        dom_more = 0;
        for k = 1 : M        
            if (x(i,V + k) < x(j,V + k))
                dom_less = dom_less + 1;
            elseif (x(i,V + k) == x(j,V + k))
                dom_equal = dom_equal + 1;
            else
                dom_more = dom_more + 1;
            end
        end
        if dom_less == 0 && dom_equal ~= M
            individual(i).n = individual(i).n + 1;
        elseif dom_more == 0 && dom_equal ~= M 
            individual(i).p = [individual(i).p j];
        end
    end
    if individual(i).n == 0 
        x(i,M + V + 1) = 1;
        F(front).f = [F(front).f i];
    end
end

while ~isempty(F(front).f)
    Q = []; 
    for i = 1 : length(F(front).f)
        if ~isempty(individual(F(front).f(i)).p)
            for j = 1 : length(individual(F(front).f(i)).p)
                individual(individual(F(front).f(i)).p(j)).n = ...
                    individual(individual(F(front).f(i)).p(j)).n - 1;
                if individual(individual(F(front).f(i)).p(j)).n == 0
                    x(individual(F(front).f(i)).p(j),M + V + 1) = ...
                        front + 1;
                    Q = [Q individual(F(front).f(i)).p(j)];
                end
            end
        end
    end
    front =  front + 1;
    F(front).f = Q;
end

[temp,index_of_fronts] = sort(x(:,M + V + 1));
for i = 1 : length(index_of_fronts)
    sorted_based_on_front(i,:) = x(index_of_fronts(i),:);
end
current_index = 0;

%% Crowding distance

for front = 1 : (length(F) - 1)
    distance = 0;
    y = [];
    previous_index = current_index + 1;
    for i = 1 : length(F(front).f)
        y(i,:) = sorted_based_on_front(current_index + i,:);
    end
    current_index = current_index + i;
    sorted_based_on_objective = [];
    for i = 1 : M
        [sorted_based_on_objective, index_of_objectives] = ...
            sort(y(:,V + i));
        sorted_based_on_objective = [];
        for j = 1 : length(index_of_objectives)
            sorted_based_on_objective(j,:) = y(index_of_objectives(j),:);
        end
        f_max = ...
            sorted_based_on_objective(length(index_of_objectives), V + i);
        f_min = sorted_based_on_objective(1, V + i);
        y(index_of_objectives(length(index_of_objectives)),M + V + 1 + i)...
            = Inf;
        y(index_of_objectives(1),M + V + 1 + i) = Inf;
        for j = 2 : length(index_of_objectives) - 1
            next_obj  = sorted_based_on_objective(j + 1,V + i);
            previous_obj  = sorted_based_on_objective(j - 1,V + i);
            if (f_max - f_min == 0)
                y(index_of_objectives(j),M + V + 1 + i) = Inf;
            else
                y(index_of_objectives(j),M + V + 1 + i) = ...
                    (next_obj - previous_obj)/(f_max - f_min);
            end
        end
    end
    distance = [];
    distance(:,1) = zeros(length(F(front).f),1);
    for i = 1 : M
        distance(:,1) = distance(:,1) + y(:,M + V + 1 + i);
    end
    y(:,M + V + 2) = distance;
    y = y(:,1 : M + V + 2);
    z(previous_index:current_index,:) = y;
end
f = z();
end


%% Bid Selection Code
function f = tournament_selection(chromosome, pool_size, tour_size)
[pop, variables] = size(chromosome);
rank = variables - 1;
distance = variables;

for i = 1 : pool_size
    for j = 1 : tour_size
        candidate(j) = round(pop*rand(1));
        if candidate(j) == 0
            candidate(j) = 1;
        end
        if j > 1
            while ~isempty(find(candidate(1 : j - 1) == candidate(j)))
                candidate(j) = round(pop*rand(1));
                if candidate(j) == 0
                    candidate(j) = 1;
                end
            end
        end
    end
    for j = 1 : tour_size
        c_obj_rank(j) = chromosome(candidate(j),rank);
        c_obj_distance(j) = chromosome(candidate(j),distance);
    end
    min_candidate = ...
        find(c_obj_rank == min(c_obj_rank));
    if length(min_candidate) ~= 1
        max_candidate = ...
            find(c_obj_distance(min_candidate) == max(c_obj_distance(min_candidate)));
        if length(max_candidate) ~= 1
            max_candidate = max_candidate(1);
        end
        f(i,:) = chromosome(candidate(min_candidate(max_candidate)),:);
    else
        f(i,:) = chromosome(candidate(min_candidate(1)),:);
    end
end
end


%% Cross-Variant Code
function f  = genetic_operator(parent_chromosome, M, V, Nopt, max_range, mu, mum, l_limit, u_limit, newinp, Qtarget, Qm0_event, NamePara, TankPara, ControlPara)
[N,m] = size(parent_chromosome);

clear m
p = 1;
was_crossover = 0;
was_mutation = 0;

for i = 1 : N
    if rand(1) < 0.9
        child_1 = [];
        child_2 = [];
        parent_1 = round(N*rand(1));
        if parent_1 < 1
            parent_1 = 1;
        end
        parent_2 = round(N*rand(1));
        if parent_2 < 1
            parent_2 = 1;
        end
        while isequal(parent_chromosome(parent_1,:),parent_chromosome(parent_2,:))
            parent_2 = round(N*rand(1));
            if parent_2 < 1
                parent_2 = 1;
            end
        end
        parent_1 = parent_chromosome(parent_1,:);
        parent_2 = parent_chromosome(parent_2,:);
        for j = 1 : V
            u(j) = rand(1);
            if u(j) <= 0.5
                bq(j) = (2*u(j))^(1/(mu+1));
            else
                bq(j) = (1/(2*(1 - u(j))))^(1/(mu+1));
            end
            child_1(j) = ...
                0.5*(((1 + bq(j))*parent_1(j)) + (1 - bq(j))*parent_2(j));
            child_2(j) = ...
                0.5*(((1 - bq(j))*parent_1(j)) + (1 + bq(j))*parent_2(j));
            if child_1(j) > u_limit(j)
                child_1(j) = u_limit(j);
            elseif child_1(j) < l_limit(j)
                child_1(j) = l_limit(j);
            end
            if child_2(j) > u_limit(j)
                child_2(j) = u_limit(j);
            elseif child_2(j) < l_limit(j)
                child_2(j) = l_limit(j);
            end
        end
        child_1(:,V + 1: M + V) = evaluate_objective(child_1, M, V, Nopt, max_range, newinp, Qtarget, Qm0_event, NamePara, TankPara, ControlPara);
        child_2(:,V + 1: M + V) = evaluate_objective(child_2, M, V, Nopt, max_range, newinp, Qtarget, Qm0_event, NamePara, TankPara, ControlPara);
        was_crossover = 1;
        was_mutation = 0;
    else%if >0.9
        parent_3 = round(N*rand(1));
        if parent_3 < 1
            parent_3 = 1;
        end
        child_3 = parent_chromosome(parent_3,:);
        for j = 1 : V
            r(j) = rand(1);
            if r(j) < 0.5
                delta(j) = (2*r(j))^(1/(mum+1)) - 1;
            else
                delta(j) = 1 - (2*(1 - r(j)))^(1/(mum+1));
            end
            child_3(j) = child_3(j) + delta(j);
            if child_3(j) > u_limit(j)
                child_3(j) = u_limit(j);
            elseif child_3(j) < l_limit(j)
                child_3(j) = l_limit(j);
            end
        end
        child_3(:,V + 1: M + V) = evaluate_objective(child_3, M, V, Nopt, max_range, newinp, Qtarget, Qm0_event, NamePara, TankPara, ControlPara);
        was_mutation = 1;
        was_crossover = 0;
    end% if <0.9
    if was_crossover
        child(p,:) = child_1;
        child(p+1,:) = child_2;
        was_cossover = 0;
        p = p + 2;
    elseif was_mutation
        child(p,:) = child_3(1,1 : M + V);
        was_mutation = 0;
        p = p + 1;
    end
end

f = child;
end


%% Generate new populations (elite strategy)
function f  = replace_chromosome(intermediate_chromosome, M, V,pop)

[N, m] = size(intermediate_chromosome);
[temp,index] = sort(intermediate_chromosome(:,M + V + 1));

clear temp m
for i = 1 : N
    sorted_chromosome(i,:) = intermediate_chromosome(index(i),:);
end

max_rank = max(intermediate_chromosome(:,M + V + 1));

previous_index = 0;
for i = 1 : max_rank
    current_index = max(find(sorted_chromosome(:,M + V + 1) == i));
    if current_index > pop
        remaining = pop - previous_index;
        temp_pop = ...
            sorted_chromosome(previous_index + 1 : current_index, :);
        [temp_sort,temp_sort_index] = ...
            sort(temp_pop(:, M + V + 2),'descend');
        for j = 1 : remaining
            f(previous_index + j,:) = temp_pop(temp_sort_index(j),:);
        end
        return;
    elseif current_index < pop
        f(previous_index + 1 : current_index, :) = ...
            sorted_chromosome(previous_index + 1 : current_index, :);
    else
        f(previous_index + 1 : current_index, :) = ...
            sorted_chromosome(previous_index + 1 : current_index, :);
        return;
    end
    previous_index = current_index;
end
end
