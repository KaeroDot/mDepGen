function [Functions Nodes] = getAllFunDefsAndCalls(File, Specials) %<<<1

% structure Function:
% .Name - name of function as used in Octave
% .ID - identificator of function
% .SubFunction - is subfunction of some script?
% .GraphName - name of function as will appear in graph

% structure Node:
% .Parent - Function where the call happens
% .Call - ID of called Function
% .LineNo - line number where the call happens
% .Special - if called function is Special

        % initialize structures:
        Functions.Name = [];
        Functions.ID = [];
        Functions.SubFunction = [];
        Functions.GraphName = [];
        Nodes.Parent = [];
        Nodes.Call = [];
        Nodes.LineNo = [];
        Nodes.Special = [];

        [tmp tmp2 tmp3] = fileparts(File);
        CurFileName = tmp2;

        LineNo = 1;
        FunctionsFound = 0;
        CurrentFunction = '';

        fid = fopen (File);
        Line = fgetl (fid);
        while not(feof(fid))
                % parse line and identify function definition %<<<2
                [S, E, TE, M, T, NM, SP] = regexpi (Line, '\s*function\s+(\S+)\s*\(');
                % testing lines for this regexp: %<<<3
                %function aa( iiii
                %function aa ( iiii
                %        function aa( iiii
                %function aa bb( iiii
                %%function aa bb( iiii
                %#function aa bb( iiii
                %>>>3
                if ~isempty(T)
                        % function definition found
                        tmp = struct();
                        tmp.Name = T{1}{1};
                        tmp.ID = GetFunctionID(CurFileName, T{1}{1});
                        % first found function is not subfunction - is it proper assumption? XXX
                        tmp.SubFunction = not(not(FunctionsFound));
                        tmp.GraphName = GetFunctionGraphName(CurFileName, T{1}{1}, tmp.SubFunction);
                        Functions(end+1) = tmp;
                        % set flags for next loop iterations:
                        CurrentFunction = tmp;
                        FunctionsFound = FunctionsFound + 1;
                else
                        % remove parts after comment characters:
                        Line = strsplit(Line, '%'){1};
                        Line = strsplit(Line, '#'){1};
                        % parse line and identify any function call  %<<<2
                        [S, E, TE, M, T, NM, SP] = regexpi (Line, '([a-zA-Z_][a-zA-Z_0-9]+)\s*\(');
                        % testing lines for this regexp: %<<<3
                        %aaa=fun(iii
                        %aaa = fun(iii
                        %aaa = fun (iii
                        %aaa = 5.*fun(iii
                        %aaa = 5.*6fun(iii
                        %aaa = 5.*6fun(iii); aaa = 5.*6fun(iii
                        %aaa=fun(iii
                        %%aaa = fun (iii
                        %aaa = fun%(iii
                        %#aaa = fun (iii
                        %>>>3
                        if ~isempty(T)
                                for i = 1:length(T)
                                        tmp = T{1,i}{1};
                                        Node.Parent = CurrentFunction;
                                        Node.Call = GetFunctionID(tmp, tmp); % assumption this ID is correctly created?
                                        Node.LineNo = LineNo;
                                        Node.Special = any(strcmp(tmp, Specials));
                                        Nodes(end+1) = Node;
                                endfor
                        endif
                        % parse line and identify any special functions calls  %<<<2
                        % this is to find function calls not followed by parenthesis (like 'disp a')
                        % however to find it, function has to be in Specials
                        % remove line after comments:
                        finds = cellfun(@strfind, {Line}, Specials, 'UniformOutput', false);
                        for i=1:length(finds)
                                if ~isempty(finds{i})
                                        % some special found
                                        Node.Parent = CurrentFunction;
                                        Node.Call = GetFunctionID(tmp, tmp); % assumption this ID is correctly created?
                                        Node.LineNo = LineNo;
                                        Node.Special = 1;
                                        Nodes(end+1) = Node;
                                        % XXX if here would be deduplication, system can be used to make a
                                        % 'flowchart'. without deduplication, special nodes produced here can be the same
                                        % as found in previous regexpi section
                                endif
                        endfor
                endif
                % for next loop iteration
                Line = fgetl (fid);
                LineNo = LineNo+1;
        end
        fclose(fid);
        % remove first empty structures:
        Functions(1) = [];
        Nodes(1) = [];

        %           % subfunctions:
        %           SubFunctions = {Function.Name}([Function.SubFunction]);
        %           for i = 1:length(Nodes)
        %                   if any(cellfun(@strcmp, {Nodes{i}.Call}, SubFunctions))



        %           % TADY BY SE MELY PROJIT VSECHNY NODY A CALLY a podivat se 
        %           % jestli se vola podfunkce v ramci souboru nebo funkce mimo soubor a podle toho upravit jmena callu
endfunction % getAllFunDefsAndCalls

function GraphName = GetFunctionGraphName(CurFileName, FunctionName, isSubfunction)
        if isSubfunction
                GraphName = [FunctionName '(' CurFileName ')'];
        else
                GraphName = FunctionName;
        endif
endfunction

function ID = GetFunctionID(CurFileName, FunctionName)
        ID = [CurFileName '>' FunctionName];
endfunction

% vim modeline: vim: foldmarker=%<<<,%>>> fdm=marker fen ft=octave textwidth=1000
