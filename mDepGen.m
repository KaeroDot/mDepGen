## Copyright (C) 2017 Martin Šíra %<<<1
##

## -*- texinfo -*-
## @deftypefn  {Function File} @var{} = mDepGen (@var{inDir}, @var{MainFunction})
## @deftypefnx {Function File} @var{} = mDepGen (@var{inDir}, @var{MainFunction}, @var{GraphFileName})
## @deftypefnx {Function File} @var{} = mDepGen (@var{inDir}, @var{MainFunction}, @var{GraphFileName}, @var{Specials})
## @deftypefnx {Function File} @var{} = mDepGen (..., @var{property}, @var{value})
## 
## Input variables:
## @table @samp
## @item @var{inDir} - Directory containing m-files to be processed.
## @item @var{MainFunction} - file name of a main function of the
##      dependency. Either a full path to the m-file or only a file name.
##      In the last case a @var{inDir} will be prepended to the file name.
## @item @var{GraphFileName} - file name of a resulted graph. Either 
##      a full path of the graph or only a file name. In the last case 
##      a @var{inDir} will be prepended to the file name.
## @item @var{Specials} - Cell of character string with function names.
##      These functions will be displayed in the graph even if not found
##      in m-files in specified path @var{inDir}.
## @end table
##
## Multiple property-value pairs may be specified, but they must
## appear in pairs. Properties and default values:
## @table @props
## @item 'graphtype' - type of output graph. Possible values:
##      @table @gt
##      @item 'dependency' - Graph of dependency. Default value.
##      @end table
##      Other possibilities are not yet implemented.
## @item 'plotall' - all function calls are plotted. If set, the resulted
##      graph can be quite large. Default value: 0.
## @end table
## ## Example 1:
## @example
## XXX
## @end example
## @end deftypefn

## Author: Martin Šíra <msiraATcmi.cz>
## Created: 2017
## Version: 0.1
## Keywords: dependency, graph
## Script quality:
##   Tested: no
##   Contains help: no
##   Contains example in help: no
##   Contains tests: no
##   Contains demo: no
##   Checks inputs: no
##   Optimized: no

% Code help and descriptions %<<<1
% Assumptions:
%       1, first function definition in a m-file is not a subfunction.
%
% Internally two structures are used:
%
% structure Function (like Parent, Children):
%     .Name - Name of function as used in script file.
%     .ID - Identificator of function. Composition of file name 
%               (without .m extension), separator and function 
%               name. See function GetFunctionID.
%     .SubFunction - Nonzero if function is subfunction (second function 
%               in function or script file).
%     .GraphName - Name of function as will appear in graph. See
%               function GetFunctionGraphName.
%     .Special - Nonzero if function is special (i.e. set as input parameter
%               or same name as some m-file.
%
% structure Node (where calling of function happens)
%     .ParentFunction - structure Function describing function where the call happens.
%     .ChildrenFunctionName - name of called function - this is needed only temporary, because during parsing
%               of the m-file it is not yet known if the called function is subfunction or not. After all parsing
%               the .ChildrenFunction is filled in properly.
%     .ChildrenFunction - structure Function describing called function.
%     .LineNo - Line number where the call happens.
%
% structure Settings (settings of all various things)
%       .GraphType - which type of graph will be plotted. either 'dependency' or 'flowchart'
%       .PlotMainFuns - main functions of found m files will be plotted
%       .PlotSubFuns - subfunctions of found m files will be plotted
%       .PlotSpecials - specials as set by user will be plotted
%       .PlotOtherFuns - other functions found in m files
%       .Specials - cell of strings with special functions as set by user
%       .Forbidden - cell of strings with forbidden (not to be plotted) functions as set by user
%       .mFileNames - cell of strings with names of m files found in directories
%
% 2DO:
% add recursion limit
% workflow graph
% plot only specials

% mDepGen %<<<1
function mDepGen(inDir, MainFunction, GraphFile='Graph', Specials={''}, Forbidden={''}, varargin)
        % only for testing: %<<<2
        inDir = 'test_functions_complex';
        MainFunction = 'test_functions_complex/main.m';
        GraphFileName = 'test_functions_complex';
        Specials = {''};

        inDir = 'test_functions_simple';
        MainFunction = 'test_functions_simple/main.m';
        GraphFileName = 'test_functions_simple';

        inDir = '.';
        MainFunction = 'mDepGen.m';
        GraphFileName = 'mDepGen';

        % -------------------- format and check inputs -------------------- %<<<2
        % format and check input directory %<<<3
        inDir = EnsureProperDirFormat(inDir);
        if exist(inDir, 'dir') ~= 7
                error(['Input directory `' inDir '` not found!'])
        endif
        % format and check main function file name %<<<3
        [di na ex] = fileparts(MainFunction);
        % if main function is only file name:
        if isempty(di)
                % prepend full path to it:
                MainFunction = fullfile(inDir, MainFunction);
        endif
        % check main function existence
        if not(exist(inDir, 'file'))
                error(['Main function `' MainFunction '` not found!'])
        endif
        MainFunctionFullPath = MainFunction;
        MainFunctionName = na;
        % format and check output graph file name %<<<3
        [di na ex] = fileparts(GraphFile);
        % if graph is only file name:
        if isempty(di)
                % prepend full path to it:
                GraphFileFullPath = fullfile(inDir, GraphFile);
        endif
        % format and check specials function names %<<<3
        Specials = Specials(:)';
        if not(iscellstr(Specials))
                error('`Specials` must be a cell of character strings!')
        endif
        % remove empty cells:
        Specials = Specials(not(cellfun('isempty', Specials)));
        Settings.Specials = Specials;
        % format and check forbidden function names %<<<3
        Forbidden = Forbidden(:)';
        if not(iscellstr(Forbidden))
                error('`Forbidden` must be a cell of character strings!')
        endif
        Settings.Forbidden = Forbidden;
        % format and check variable arguments %<<<3
        [reg, ...
                Settings.GraphType, ...
                Settings.PlotMainFuns, ...
                Settings.PlotSubFuns, ...
                Settings.PlotSpecials, ...
                Settings.PlotOtherFuns] = parseparams (varargin, ...
                        'graphtype',            'dependency', ...
                        'plotmainfuns',         1, ...
                        'plotsubfuns',          1, ...
                        'plotspecials',         1, ...
                        'plototherfuns',        0, ...
                        'plotunknownfuns',      0);

        % -------------------- files parsing -------------------- %<<<2
        % search all .m files in input directory and subdirectories:
        mFiles = GetAllmFiles(inDir, '.*.m$');
        [tmp1 tmp2 tmp3] = cellfun(@fileparts, mFiles, 'UniformOutput', false);
        % add all found file names to settings so they can be found even if not called followed by parenthesis
        Settings.mFileNames = tmp2(:);
        % remove empty cells:
        Settings.mFileNames = Settings.mFileNames(not(cellfun('isempty', Settings.mFileNames)));
        % in all m-files find functions and nodes: 
        [Functions Nodes] = cellfun(@GetAllFunDefsAndCalls, mFiles, {Settings}, 'UniformOutput', 0);
        % now the Functions is cell containing Function structures, one cell per file, and
        % Nodes is cell containing Node structures, one cell per file. Nodes are as found in file, i.e.
        % if something is called multiple times, it is multiple times in Nodes.
        disp([num2str(length([Functions{:}])) " function definitions and " num2str(length([Nodes{:}])) " calls (nodes) found"])

        % OBSOLETE, delete: %<<<2
        % method=0
        % if method
                % % -------------------- simple graph generation -------------------- 
                % % make graph node lines:
                % GraphLines = {};
                % for i = 1:length(Nodes)
                        % Node = Nodes{i};
                        % for i = 1:length(Node)
                                % GraphLines{end+1} = sprintf('"%s" -> "%s";', Node(i).ParentFunction.ID, Node(i).CallID);
                        % endfor
                % endfor
                % % deduplicate:
                % GraphLines = unique(GraphLines); % unfortunately unique of struct does not work
                % % make graph itself
                % Graph = '/* Generated by mDepGen */';
                % Graph = [Graph "\ndigraph dep {\nnode [shape = box];"];
                % for i = 1:length(GraphLines)
                        % Graph = [Graph "\n" GraphLines{i}];
                % endfor
                % Graph = [Graph "\n}"];
                % % print graph string into .dot file
                % fid = fopen ([GraphFileName '.dot'],'w');
                % fprintf(fid, Graph);
                % fclose(fid);
                % disp("Graph written")

        AllNodes = [Nodes{:}];
        AllFunctions = [Functions{:}];
        % probably not needed anymore XXX:
        % AllNodes = FillInCallFunction(AllFunctions, AllNodes);

        % this is needed so nodes with all same but line number will be deduplicated:

        % -------------------- dependency graph -------------------- %<<<2
        if strcmpi(Settings.GraphType, 'dependency')
                % -------------------- nodes processing -------------------- %<<<2
                % all calls of children in one parent (one function) are considered as the same, so for
                % easy deduplication line numbers are removed:
                AllNodes = RemoveLineNo(AllNodes);
                % deduplicate and sort:
                SortedAllNodes = SortNodesByParent(AllNodes);
                % now SortedAllNodes is cell, one cell per function, with unique Nodes.
                % Find first parent - cell with nodes belonging to main function:
                ind = [];
                for j = 1:length(SortedAllNodes)
                        % XXX here should be comparison against filenamepart of MainFunction, but it contains whole path and extension
                        ind(j) = strcmp(MainFunctionName, SortedAllNodes{j}(1).ParentFunction.Name);
                endfor
                if not(any(ind))
                        error(['Main function `' MainFunctionName '` not found in Sorted Nodes. Check input parameter `MainFunction`.'])
                endif
                id = find(ind);
                if length(id) > 2
                        error('Multiple cells containing the main function were found. Sorting is not working properly. This is internal error.')
                endif
                % prepare recursion:
                Parent = SortedAllNodes{id}(1).ParentFunction;
                Nodes = SortedAllNodes{id};
                WalkList = [{Parent.ID}];
                % start recursion:
                GraphLines = WalkThroughRecursively(Parent, Nodes, WalkList, SortedAllNodes);

        % -------------------- flowchart graph -------------------- %<<<2
        elseif strcmpi(Settings.GraphType, 'flowchart')
                error('not yet implemented')
                % XXX
        endif

        % -------------------- final graph generation -------------------- %<<<2
        % join header, graph lines and ending together
        Graph = '/* Generated by mDepGen */';
        Graph = [Graph "\ndigraph dep {\nnode [shape = box];"];
        for i = 1:length(GraphLines)
                Graph = [Graph "\n" GraphLines{i}];
        endfor
        Graph = [Graph "\n}"];

        % -------------------- dot file creation -------------------- %<<<2
        fid = fopen ([GraphFileFullPath '.dot'],'w');
        fprintf(fid, Graph);
        fclose(fid);
        disp("Graph written")

        % -------------------- pdf file creation -------------------- %<<<2
        % call GraphViz
        [STATUS, OUTPUT] = system(['dot -Tpdf "' GraphFileName '.dot" -o "' GraphFileName '.pdf"']);
        if STATUS
                error(["GraphViz failed. Output was:\n" OUTPUT])
        else
                disp("Pdf created")
        endif
        disp("Done")

endfunction % mDepGen

% EnsureProperDirFormat %<<<1
function Dir = EnsureProperDirFormat(Dir)
% Ensures the directory the directory character string ends with a file separator.
% maybe this is not needed if only fullfile is used to concatenate everything XXX
        if not(strcmp(Dir(end), filesep))
                Dir = [Dir filesep];
        endif
endfunction % EnsureProperDirFormat

% GetAllmFiles %<<<1
function fileList = GetAllmFiles(dirName, pattern = '.*')
% Recursively search files in selected directory and subdirectories and returns
% cell of character strings with relative paths and filenames.
% Second parameter pattern is REGULAR expression, i.e. all files with .m extension is
% searched as: '.*.m$', not as '*.m'!

        dirData = dir(dirName);      % Get the data for the current directory
        dirIndex = [dirData.isdir];  % Find the index for directories
        fileList = {dirData(~dirIndex).name}';  %' % Get a list of the files
        if ~isempty(fileList)
                fileList = cellfun(@(x) fullfile(dirName,x),... % Prepend path to files
                        fileList,'UniformOutput',false);
                matchstart = regexp(fileList, pattern);
                fileList = fileList(~cellfun(@isempty, matchstart));
        endif
        subDirs = {dirData(dirIndex).name};  % Get a list of the subdirectories
        validIndex = ~ismember(subDirs,{'.','..'});  % Find index of subdirectories
                                                     %   that are not '.' or '..'
        for iDir = find(validIndex)                  % Loop over valid subdirectories
                nextDir = fullfile(dirName,subDirs{iDir});    % Get the subdirectory path
                fileList = [fileList; GetAllmFiles(nextDir, pattern)];  % Recursively call getAllFiles
        endfor
endfunction % getAllmFiles

% GetAllFunDefsAndCalls %<<<1
function [Functions Nodes] = GetAllFunDefsAndCalls(File, Settings)
% In a file, finds all functions defined and all callings of other funtions (Nodes).
% Function have to be defined as `function somefunction(`.
% Called functions must be called as `somefunction(` to be found.
% If called function is listed in Settings.Specials or Settings.Forbidden or Settings., the parenthesis is not required.

        % prepare structures for easy array building:
        % (this will prevent adding structures into array with different fields)
        Functions.ID = '';
        Functions.Name = '';
        Functions.GraphName = '';
        Functions.SubFunction = 0;
        Functions.Special = 0;

        % following two fields are only temporary and are removed at the end:
        Nodes.ParentFunctionName = [];
        Nodes.ChildrenFunctionName = [];
        Nodes.ParentFunction = [];
        Nodes.ChildrenFunction = [];
        Nodes.LineNo = 0;

        % get name of current m-file:
        [tmp tmp2 tmp3] = fileparts(File);
        CurFileName = tmp2;

        % number of current line in m-file:
        LineNo = 1;
        % if any function in a m-file was already found or not:
        FunctionsFound = 0;
        % name of current function in a m-file:
        CurrentFunction = '';

        % open the m-file:
        fid = fopen (File);
        Line = fgetl (fid);
        % parse line by line and search only function definitions now %<<<2
        while not(feof(fid))
                Line = PrepareLine(Line);
                % get function definition
                FunctionDefinitionName = ParseLineGetFunctionDefinition(Line);
                if ~isempty(FunctionDefinitionName)
                        % function definition found, create new Function structure and set values:
                        newFunction = struct();
                        newFunction.Name = FunctionDefinitionName;
                        newFunction.ID = GetFunctionID(CurFileName, newFunction.Name);
                        % first found function is not subfunction:      
                        % (this is probably an Assumption!)
                        newFunction.SubFunction = not(not(FunctionsFound));
                        newFunction.GraphName = GetFunctionGraphName(CurFileName, newFunction.Name, newFunction.SubFunction);
                        % strfind -> strcmp XXX
                        newFunction.Special = not(isempty(cell2mat(strfind(Specials, newFunction.Name))));
                        % set flags for next loop iterations:
                        CurrentFunction = newFunction.Name;
                        FunctionsFound = FunctionsFound + 1;
                        Line = '';
                        if not( isempty(newFunction) || isempty(fieldnames(newFunction)) )
                                Functions = [Functions newFunction];
                        endif
                endif
                if ~isempty(Line)
                        % if Line is not empty, add it to Lines for next loop:
                        Lines{end+1} = Line;
                        LineNumbers(end+1) = LineNo;
                endif
                % for next loop iteration:
                Line = fgetl(fid);
                LineNo = LineNo+1;
        end
        fclose(fid);
        % remove first empty structure:
        Functions(1) = [];
        % second iteration searching for nodes. now all subfunctions are known therefore can be identified even if called without parenthesis:
        for i = 1:length(Lines)
                % XXXXXXXXXXXXXX
                newNodes = ParseLineGetNode(CurFileName, CurFunctionName, Lines{i}, LineNo(i), FunctionsFound, Settings.Specials, CurrentFunction);
        endfor
        % remove first empty structure:
        Nodes(1) = [];

        % add to Nodes proper Parent and Children Function structures according found subfunctions %<<<2
        % i.e. if Node.ChildrenFunctionName = external_function, output will be external_function>external_function,
        % but if Node.ChildrenFunctionName = sub_function, output will be cur_file_name>sub_function
        % found subfunctions:
        SubFunctions = {Functions.Name}([Functions.SubFunction]);
        for i = 1:length(Nodes)
                % parent %<<<3
                Parent = [];
                Parent.Name = Nodes(i).ParentFunctionName;
                % XXX tady to nekdy dela problem? asi kdyz zadne funkce a subfunkce nejsou nalezeny
                Parent.SubFunction = any(strcmp(Nodes(i).ParentFunctionName, SubFunctions));
                if Parent.SubFunction
                        Parent.ID = GetFunctionID(CurFileName, Parent.Name);
                        Parent.GraphName = GetFunctionGraphName(CurFileName, Parent.Name, 1);
                else
                        % assupmtion: if parent function is not subfunction, the file name 
                        % and function name is the same.
                        Parent.ID = GetFunctionID(Parent.Name, Parent.Name);
                        Parent.GraphName = GetFunctionGraphName(Parent.Name, Parent.Name, 0);
                endif
                Parent.Special = any(strcmp(Parent.Name, Settings.Specials));
                Nodes(i).ParentFunction = Parent;
                % children %<<<3
                Children = [];
                Children.Name = Nodes(i).ChildrenFunctionName;
                % XXX tady to nekdy dela problem? asi kdyz zadne funkce a subfunkce nejsou nalezeny
                Children.SubFunction = any(strcmp(Nodes(i).ChildrenFunctionName, SubFunctions));
                if Children.SubFunction
                        Children.ID = GetFunctionID(CurFileName, Children.Name);
                        Children.GraphName = GetFunctionGraphName(CurFileName, Children.Name, 1);
                else
                        % assupmtion: if called function is not subfunction, the file name 
                        % and function name is the same.
                        Children.ID = GetFunctionID(Children.Name, Children.Name);
                        Children.GraphName = GetFunctionGraphName(Children.Name, Children.Name, 0);
                endif
                Children.Special = any(strcmp(Children.Name, Settings.Specials));
                Nodes(i).ChildrenFunction = Children;
                % >>>3
        endfor
        % remove excess fields:
        Nodes = rmfield(Nodes, 'ParentFunctionName');
        Nodes = rmfield(Nodes, 'ChildrenFunctionName');
endfunction % GetAllFunDefsAndCalls

% PrepareLine %<<<1
function Line = PrepareLine(Line)
% removes strings and comments from line from m file
        % remove parts after comment characters from Line
        Line = strsplit(Line, '%'){1};
        Line = strsplit(Line, '#'){1};
        % remove content inside strings in between '' and "":
        Line = regexprep(Line, "'.*?'", "''");
        Line = regexprep(Line, '".*?"', '""');
        % remove spaces to get empty string inf no real content:
        Line = strtrim(Line);
endfunction % PrepareLine

% ParseLineGetNode %<<<1
function [newNodes, CurrentFunction] = ParseLineGetNode(CurFileName, Line, LineNo, FunctionsFound, Specials, CurrentFunction)
% parse line from script in file CurFileName and search for function definition Function or 
% function call Node. FunctionsFound is number of already found functions, Specials is cell of string
% of special functions, CurrentFunction is string of in which function the line is (for nodes, not for function definition)
        % initialization:
        newFunction = struct();
        newNodes = struct();
        % -------------------- parse line and identify any function call -------------------- %<<<2
        FunctionNames = ParseLineGetAnyFunctionCalls(Line);
        if ~isempty(FunctionNames)
                for i = 1:length(FunctionNames)
                        Node = struct();
                        % what if function not yet found? e.g. in script? XXX
                        Node.ParentFunctionName = CurrentFunction;
                        Node.ParentFunction = [];
                        Node.LineNo = LineNo;
                        % fields of next two lines will be changed to proper values at the end of script:
                        Node.ChildrenFunctionName = FunctionNames{i}; 
                        Node.ChildrenFunction = [];
                        newNodes(end+1) = Node;
                endfor % length(FunctionNames)
        endif % ~isempty(FunctionNames)
        % -------------------- parse line and identify any special functions calls -------------------- %<<<2
        SpecialFunctionNames = ParseLineGetSpecialFunctionCalls(Line, Specials);
        for i=1:length(SpecialFunctionNames)
                Node = struct();
                % some special found
                Node.ParentFunctionName = CurrentFunction;
                Node.ParentFunction = [];
                Node.LineNo = LineNo;
                % fields of next two lines will be changed to proper values at the end of script:
                Node.ChildrenFunctionName = Specials{i};
                Node.ChildrenFunction = [];
                % try to find if this node already exists (i.e. has been added in previous section
                % identifying any (not only Special) function call). it is to prevent duplicate values:
                if not(any(arrayfun(@isequal, newNodes, Node)))
                        % node do not exist, add it:
                        newNodes(end+1) = Node;
                endif
        endfor % length(SpecialFunctionNames)
        % remove first element because of struct initialization newNodes = struct()
        newNodes = newNodes(2:end);
endfunction % ParseLineGetNode

% ParseLineGetFunctionDefinition %<<<1
function FunctionDefinitionName = ParseLineGetFunctionDefinition(Line)
% parse line and return function name from function definition if any found
% XXX what if more functions at a line? this can find only one function definition at a line. Assumption!
        FunctionDefinitionName = '';
        % regexp:
        [S, E, TE, M, T, NM, SP] = regexpi (Line, 'function\s+(?:.+=\s*|)([^=\s]+)\s*\(.*\)');
        % testing lines for this regexp: %<<<2
        %function  aa( iiii )
        %function  aa  ( iiii )
        %        function  aa( iiii )
        %function rr=aa( iiii )
        %function rr  =  aa( iiii )
        %function rr=  aa( iiii )
        %function rr  =aa( iiii )
        % should not find following:
        %functionaa( iiii )
        %functionrr=aa( iiii )
        %function =aa( iiii )
        %function aa( iiii
        %>>>2
        if ~isempty(T)
                FunctionDefinitionName = T{1}{1};
        endif
endfunction % ParseLineGetFunctionDefinition

% ParseLineGetAnyFunctionCalls %<<<1
function FunctionNames = ParseLineGetAnyFunctionCalls(Line)
% parse line and return function name from function call if any found
% XXX this finds everything, even something like: variable(5) = 5
% XXX takes also things in '' and ""
        [S, E, TE, M, FunctionNames, NM, SP] = regexpi (Line, '([a-zA-Z_][a-zA-Z_0-9]*)\s*\(.*?\)');
        % testing lines for this regexp: %<<<2
        %aaa=f(iii)
        %aaa=fun(iii)
        %aaa=  fun(iii)
        %aaa  =fun(iii)
        %aaa  =  fun(iii)
        %aaa  =  fun  (iii)
        %aaa = 5.*fun(iii)
        %aaa = 5.*6fun(iii)
        %aaa = 5.*f6(iii)
        %aaa = 5.*6fun(iii); aaa = 5.*6fun2(iii)
        %should not match following:
        %aaa=(iii)
        %aaa=5(iii)
        %aaa=f(
        %>>>2
        FunctionNames = [FunctionNames{:}];
endfunction % ParseLineGetAnyFunctionCall

% ParseLineGetSpecialFunctionCalls %<<<1
function SpecialFunctionNames = ParseLineGetSpecialFunctionCalls(Line, Specials)
% parse line and return function name from special function call if any found
% this is to find function calls not followed by parenthesis (like 'disp a')
% however to find it, function has to be in Specials
% XXX takes also things in '' and ""
                % strfind -> strcmp XXX
        tmp = strfind(Line, Specials);
        SpecialFunctionNames = Specials(not(cellfun(@isempty, tmp)));
endfunction % ParseLineGetAnyFunctionCall

% GetFunctionGraphName %<<<1
function GraphName = GetFunctionGraphName(CurFileName, FunctionName, isSubfunction)
% generate name of function as will be shown in graph
        if isSubfunction
                GraphName = [FunctionName ' (' CurFileName ')'];
        else
                GraphName = FunctionName;
        endif
endfunction % GetFunctionGraphName

% GetFunctionID %<<<1
function ID = GetFunctionID(FileName, FunctionName)
% generates unique function identifier from m-file name and function name
        ID = [FileName '>' FunctionName];
endfunction % GetFunctionID

% WalkThroughRecursively %<<<1
function [GraphLines SortedAllNodesOut] = WalkThroughRecursively(Parent, Nodes, WalkList, SortedAllNodes)
% function walks through functions and prepares graph lines for dependency graph
% function is able to recognize recursions in m-files callings thanks the WalkList
        GraphLines = {};
        % for all nodes/children
        for i=1:length(Nodes)
                disp([num2str(i) '/' num2str(length(Nodes))])
                disp([Parent.ID ' -> ' Nodes(i).ChildrenFunction.ID])
                % make node
                % if in walklist add red mark and quit
                % else 
                % recursion calling
                % Parent = current function
                % Nodes = najit ty ktere vola ??????? 
                % Walklist pridat uroven

                % check for recursions:
                if any(strcmpi(WalkList, Nodes(i).ChildrenFunction.ID))
                        disp('recursion found...')
                        % recursion found, add graph line, do not search for nodes in called function/children:
                        GraphLines(end+1) = MakeDotLine(Parent, Nodes(i).ChildrenFunction, 'recursion');
                        % when recursion, do not continue into deeper level of dependency
                else
                        disp('no recursion, adding graph line...')
                        % no recursion, add graph line:
                        GraphLines(end+1) = MakeDotLine(Parent, Nodes(i).ChildrenFunction, 'normal');
                        % find nodes in called function/children:
                        ind = [];
                        for j = 1:length(SortedAllNodes)
                                ind(end+1) = strcmp(Nodes(i).ChildrenFunction.ID, SortedAllNodes{j}(1).ParentFunction.ID);
                        endfor
                        disp('found children')
                        if any(ind)
                                id = find(ind);
                                % if multiple found - some error. sorting is not working properly. so this is error:
                                if length(id) > 1
                                        error('Multiple cells containing nodes of the children were found. Sorting is not working properly. This is internal error.')
                                endif
                                % prepare deeper level of recursion: 
                                ParentFunction = Nodes(i).ChildrenFunction;
                                NodesToChildren = SortedAllNodes{id};
                                newWalkList = [WalkList {ParentFunction.ID}];
                                disp(['new recursion to ' ParentFunction.ID])
                                [NewGraphLines SortedAllNodes] = WalkThroughRecursively(ParentFunction, NodesToChildren, newWalkList, SortedAllNodes);
                                % accumulate graph lines from deeper level of recursion:
                                GraphLines = [GraphLines NewGraphLines];
                        else
                                % no nodes in called function/children were found, nothing to do here
                        endif
                endif
        endfor
        % If this parent is finished, remove it from SortedAllNodes to prevent multiple 
        % walks in during the next loops at higher levels.
        % find the parent:
        ind = [];
        for i = 1:length(SortedAllNodes)
                ind(end+1) = strcmp(Parent.ID, SortedAllNodes{i}(1).ParentFunction.ID);
        endfor
        id = find(ind);
        if not(isempty(id))
                disp(['removing parent ' Parent.ID])
                % if multiple found - some error. sorting is not working properly. so this is error:
                if length(id) > 1
                        error('Multiple cells containing the parent were found. Sorting is not working properly. This is internal error.')
                endif
                SortedAllNodesOut = SortedAllNodes;
                SortedAllNodesOut(id) = [];
        endif
endfunction % WalkThroughRecursively

% SortNodesByParent %<<1
function SortedNodes = SortNodesByParent(AllNodes)
% sort nodes by parent functions and deduplicates them
        % get unique call functions:
        UniqueParentFunctionIDs = unique({[AllNodes(:).ParentFunction].ID});

        for i = 1:length(UniqueParentFunctionIDs)
                % find Nodes with current Parent
                tmp = strcmp(UniqueParentFunctionIDs{i}, {[AllNodes(:).ParentFunction].ID});
                % get only unique nodes:
                SortedNodes{i} = UniqueStruct(AllNodes(tmp));
        endfor
endfunction % SortNodesByParent

% RemoveLineNo %<<<1
function NodesOut = RemoveLineNo(Nodes)
% remove field LineNo from Node structure
        NodesOut = struct();
        for i = 1:length(Nodes)
                NodesOut(i) = rmfield(Nodes(i), 'LineNo');
        endfor
endfunction % RemoveLineNo

% MakeDotLine %<<<1
function GraphLine = MakeDotLine(Parent, Children, nodetype)
% generate line for .dot graph file according node type. Parent and Children are Function structures.
        if strcmpi(nodetype, 'recursion')
                app = ' [color=red];';
        else
                app = ';';
        endif
        GraphLine = {sprintf('"%s" -> "%s" %s', Parent.GraphName, Children.GraphName, app)};
endfunction

% UniqueStruct %<<<1
function OutStruct = UniqueStruct(InStruct)
% Function returns only unique structures. Function uses 
% recursion. InStruct and OutStruct are arrays of structures.

        OutStruct = [];
        % find ones equal to first one
        id = arrayfun(@isequal, InStruct(1), InStruct);
        % add the first one to output:
        OutStruct = [OutStruct InStruct(1)];
        % remove the first one and the duplicates:
        InStruct = InStruct(not(id));
        if ~isempty(InStruct)
                % recursively call itself on the rest:
                OutStruct = [OutStruct UniqueStruct(InStruct)];
        endif
endfunction % UniqueStruct

%<<<1 %>>>1

%% % FillInCallFunction %<<<1
%% function AllNodesOut = FillInCallFunction(AllFunctions, AllNodes)
%% % XXX not needed anymore? !!!
%%         % adds to nodes a .CallFunction field, which is a called Function structure:
%%         for i = 1:length(AllNodes)
%%                 % get id of Function in the Call
%%                 id = find( strcmp(AllNodes(i).CallID, {AllFunctions.ID}) );
%%                 if isempty(id)
%%                         % call is not a function in list of functions
%%                         % XXX what to do here?
%%                         % JE TO PROBLEM? XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
%%                         % JE!!!!
%%                         % tmp.Name = 'somefun';
%%                         % tmp.ID = 'somefun';
%%                         % tmp.SubFunction = 0;
%%                         % tmp.GraphName = 'somefun';
%%                         % AllNodes(i).CallFunction = tmp;
%%                 else
%%                         id = id(1);
%%                         % Set calling function in the Node
%%                         AllNodes(i).CallFunction = AllFunctions(id);
%%                         % this causes only nodes with filled in call function gets to the output:
%%                         % XXX preselection should be elsewhere
%%                         AllNodesOut(end+1) = AllNodes(i);
%%                 endif
%%         endfor
%% endfunction

% vim modeline: vim: foldmarker=%<<<,%>>> fdm=marker fen ft=octave textwidth=1000
