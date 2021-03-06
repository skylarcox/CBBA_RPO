% Copyright 2010
% Massachusetts Institute of Technology
% All rights reserved
% Developed by the Aerospace Controls Lab, MIT

%---------------------------------------------------------------------%
% Calculates marginal score of doing a task and returns the expected
% start time for the task.
%---------------------------------------------------------------------%

function [score, minStartTime, maxStartTime] = Scoring_CalcScore_RPO(CBBA_Params,agent,rsoCurr,rsoPrev,timePrev,taskNext,timeNext, CBBA_Data, tasks, newIndex)
    
dvMultiplier = 100;
lambdaDV     = -10;

% if((agent.type == CBBA_Params.AGENT_TYPES.QUAD) || ...
%    (agent.type == CBBA_Params.AGENT_TYPES.CAR))
numWeeksToEval = round(CBBA_Params.sim_years * 52,1);
 
    if(isempty(rsoPrev)) % First task in path
        startDV = 0;
        
        % Compute start time of task
        
        Output = RendezvousFunc_weeks_updated(agent,rsoCurr,CBBA_Params.JD,CBBA_Params.JD,numWeeksToEval);
        valid = find(~isnan(Output.RSO.deltaV));
        
        if ~isempty(valid)
            %dt = Output.Week(valid(1));
            %minStart = taskCurr.start + dt; % Soonest time feasible
            
            % Minimum start time is the largest of either the start of
            % task availability or a valid potential access [weeks relative
            % to JD start]
            minStartTime = max(rsoCurr.start,Output.Week(valid(1))); %Output.JD(valid(1));
            
        else
            error('Problem with timing. Valid time not found.')
            %minStart = inf;
        end
        
        %dt = sqrt((agent.x-taskCurr.x)^2 + (agent.y-taskCurr.y)^2 + (agent.z-taskCurr.z)^2)/agent.nom_vel;
        %minStart = max(taskCurr.start, agent.avail + dt);
        
    else % Not first task in path
        
        % Calculate the current delta-V required for the currently planned task(s)      
        startDV = compute_deltaV_for_sequence(agent, CBBA_Data, tasks, CBBA_Params.JD, CBBA_Params.num_weeks);
        
        
        % Put in new JD associated with previous task (NEED TimePrev)
        Output = RendezvousFunc_weeks_updated(rsoPrev,rsoCurr,timePrev,CBBA_Params.JD,numWeeksToEval);
        valid  = find(~isnan(Output.RSO.deltaV));
        
        if ~isempty(valid)
            
            % Relative weeks for reference
            dt = Output.Week(valid(1));
            minStartTime = max(rsoCurr.start, timePrev + rsoPrev.duration + dt);

            %minStart = Output.JD(valid(1));
        else
            error('Problem with timing. Valid time not found.')
            %minStart = inf;
        end
      
        
    end
    
    if(isempty(taskNext)) % Last task in path
        maxStartTime = rsoCurr.end;
    else % Not last task, check if we can still make promised task
        
        if (isempty(timePrev))
            Output = RendezvousFunc_weeks_updated(agent,rsoCurr,CBBA_Params.JD,CBBA_Params.JD,numWeeksToEval);
            %Output = RendezvousFunc_weeks(agent,taskCurr,CBBA_Params.JD,CBBA_Params.JD,numWeeksToEval);
        else
            Output = RendezvousFunc_weeks_updated(rsoPrev,rsoCurr,timePrev,CBBA_Params.JD,numWeeksToEval);
        end
        
        valid  = find(~isnan(Output.RSO.deltaV));
        
        dt = Output.Week(valid(1));
        
        %dt = sqrt((taskNext.x-taskCurr.x)^2 + (taskNext.y-taskCurr.y)^2 + (taskNext.z-taskCurr.z)^2)/agent.nom_vel;
        
        maxStartTime = min(rsoCurr.end, timeNext - rsoCurr.duration - dt); %i have to have time to do task m and fly to task at j+1
        
    end
    
    reward = rsoCurr.score; %taskCurr.value*exp(-taskCurr.lambda*(minStartTime-taskCurr.start));
    
    % Re-assess task placement to understand how the cost changes by adding a new task    
    Allocated_Tasks = CBBA_Data;
    Allocated_Tasks.path = CBBA_InsertInList(Allocated_Tasks.path, rsoCurr.id, newIndex);
    Allocated_Tasks.times = CBBA_InsertInList(Allocated_Tasks.times, minStartTime, newIndex);
    
    % Recompute the total delta-V cost to properly compute the penalty
    newDV = compute_deltaV_for_sequence(agent, Allocated_Tasks, tasks, CBBA_Params.JD, CBBA_Params.num_weeks);
    
    dvChange = newDV - startDV; %#ok<NASGU>
    remainingDV = agent.DV - newDV;
    
    penalty = dvMultiplier * exp(lambdaDV * remainingDV);

    score = reward - penalty;

    % Check if task is infeasible based on delta-V resources
    if remainingDV < 0
        % Infeasible. Set minStartTime to be after maxStartTime unless arleady
        if minStartTime < maxStartTime
            minStartTime = 2;
            maxStartTime = 1;
        end
    end

return
