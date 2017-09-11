## Copyright (C) 2017 Martin Šíra %<<<1
##

## -*- texinfo -*-
## @deftypefn  {Function File} @var{} = mDepGen (@var{inDir}, @var{StartFunction}, @var{GraphFile})
## @deftypefnx {Function File} @var{} = mDepGen (@var{inDir}, @var{StartFunction}, @var{GraphFile}, @var{Specials})
## @deftypefnx {Function File} @var{} = mDepGen (@var{inDir}, @var{StartFunction}, @var{GraphFile}, @var{Specials}, @var{Forbidden})
## @deftypefnx {Function File} @var{} = mDepGen (@var{inDir}, @var{StartFunction}, @var{GraphFile}, @var{Specials}, @var{Forbidden}, @var{property}, @var{value}, ...)
##
## Function parse all m-files in string @var{inDir}, identifies all functions 
## and calls, finds out which function calls which one, creates graph 
## @var{GraphFile} in Graphviz format starting from @var{StartFunction},
## calls Graphviz to generate graph in pdf format.
##
## This function does not provide syntax analysis of m files, it only does some 
## regular expression matching.
## 
## Recursions are identified and plotted on graph by different colour.
## m-Files in sub directories are also parsed, however function `addpath`
## is not understood.
## 
## Function calls in source code of m-files are identified as being followed
## by parenthesis `(`. However some functions are called without 
## parenthesis (like code `t=tic;`). These functions will be identified 
## only if:
## @table @samp
## @item called function is main function in an m-file,
## @item called function is sub function in an m-file,
## @item called function is listed in @var{Specials}
## @end table
## 
## Input variables in detail:
## @table @samp
## @item @var{inDir} - Directory containing m-files to be processed.
## @item @var{StartFunction} - File name of a starting function of the
##      graph. Either a full path to the m-file or only a file name.
##      In the last case a @var{inDir} will be prepended to the file name.
## @item @var{GraphFileName} - File name of a resulted graph. Either 
##      a full path of the graph or only a file name. In the last case 
##      a @var{inDir} will be prepended to the file name.
## @item @var{Specials} - Cell of character string with function names.
##      These functions will be always displayed in the graph.
## @item @var{Forbidden} - Cell of character string with function names.
##      These functions will not be displayed in the graph.
## @end table
##
## Behaviour of graph can be fine tuned by @var{property} @var{value} pairs.
## Default value is in brackets.
## @table @samp
## @item 'graphtype' (dependency) - string, type of output graph. Possible values:
##      @table @samp
##      @item 'dependency' - Graph of dependency.
##      @end table
##      For now it is the only possibility. More will maybe come in future.
## @item 'plotmainfuns' (1) - boolean, main functions (first one in m-file) will be plotted.
##      Be carefull to switching this off. This could result in empty graph.
## @item 'plotsubfuns' (1) - boolean, sub functions (second and others in m-file) will be 
##      plotted.
## @item 'plotspecials' (1) - boolean, functions listed in Specials will be 
##      plotted.
## @item 'plototherfuns' (1) - boolean, function calls followed by parenthesis `(` and 
##      existing in Octave namespace will be plotted.
## @item 'plotunknownfuns' (1) - boolean, anything resembling function call (word 
##      followed by parenthesis `(` will be plotted. Due to limitations 
##      of this program variables can be considered as function calls 
##      (i.e. code `variable(:)`).
## 
## @end table
##
## Example:
## @example
## mDepGen('.', 'mDepGen', 'example_graph', @{'fopen', 'fgetl'@}, @{'PrepareLine'@}, 'plototherfuns', 1)
## @end example
## @end deftypefn

## Author: Martin Šíra <msiraATcmi.cz>
## Created: 2017
## Version: 0.1
## Keywords: dependency, graph
## Script quality:
##   Tested: no
##   Contains help: yes
##   Contains example in help: yes
##   Contains tests: no
##   Contains demo: no
##   Checks inputs: yes
##   Optimized: no

% Code help and descriptions %<<<1
% Code flow:
% - find all .m files in directory and subdirs,
% - for all .m files parse file and:
%       - find all functions
%       - find all nodes
%       - fix functions/nodes for the case of script
% - filter functions/nodes according settings
% - according graph type:
%       - dependency graph:
%               - format nodes
%               - sort and deduplicate
%               - find starting function in sorted nodes
%               - make recursion and generate graph lines
% - print .dot file
% - call graphviz
% - call .dot->pdf conversion
%       
% Assumptions:
%       1, first function definition in a m-file is main function, not a subfunction.
%       2, only one function definition in a line of source code
%       3, if a called function is not i a list of found functions (i.e. not in parsed m-file, 
%          but builtin function etc.), it is assumed it is a main function and not a subfunction
%
% Internally three structures are used:
%
% structure Function (like Parent, Children):
%     .Name - Name of function as used in script file.
%     .ID - Identificator of function. Composition of file name (without .m extension), separator and function name. See function GetFunctionID.
%     .GraphName - Name of function as will appear in graph. See function GetFunctionGraphName.
%     .Special - Nonzero if function is set as Special by user.
%     .Script - Nonzero if function is script (no function definition found before first call)
%     .MainFunction - Nonzero if function is the main function in a m-file with multiple functions.
%     .SubFunction - Nonzero if function is the sub function in a m-file with multiple functions.
%     .Forbidden - Nonzero if function is set as Forbidden by user.
%     .Other - Nonzero if function is not found in parsed m-Files and is not Forbidden or Special.
%     .OtherUnknown - Nonzero if function is other and is not known to octave (probably false positive)
%     .FilePathName - file path and name of the file where the function is.
%     .LineNo - line number of the definition of the function.
%
% structure Node (where calling of function happens)
%     .ParentFunction - structure Function describing function where the call happens.
%     .ChildrenFunction - structure Function describing called function.
%     .ChildrenFunctionName - name of called function - this is needed only temporary, because during parsing of m-files details of children functions is not yet known. After all parsing the .ChildrenFunction is filled in properly.
%     .LineNo - Line number where the call happens.
%     .FilePathName - file path and name of the file where the node is.
%
% structure Settings (settings of all various things)
%       .GraphType - which type of graph will be plotted. either 'dependency' or 'flowchart'
%       .PlotMainFuns - main functions of found m files will be plotted
%       .PlotSubFuns - subfunctions of found m files will be plotted
%       .PlotSpecials - specials as set by user will be plotted
%       .PlotOtherFuns - other functions found in m files
%       .PlotOtherUknown - other functions found in m files even if not known by octave (possibly false positives on variables like: `variable(index) = something` )
%       .Specials - cell of strings with special functions as set by user
%       .Forbidden - cell of strings with forbidden (not to be plotted) functions as set by user
%       .mFileNames - cell of strings with names of m files found in directories
%
% 2DO:
% add recursion limit
% workflow graph

% mDepGen %<<<1
function mDepGen(inDir, StartFunction, GraphFile='Graph', Specials={}, Forbidden={}, varargin)
        % only for testing purposes: %<<<2
        % inDir = 'test_functions';
        % StartFunction = 'main.m';
        % GraphFile = 'test_functions_dependency_graph';
        % Specials = {'tic'};
        % varargin = { 'graphtype',            'dependency', ...
                        % 'plotmainfuns',         1,...
                        % 'plotsubfuns',          1,...
                        % 'plotspecials',         1,...
                        % 'plototherfuns',        1,...
                        % 'plotunknownfuns',      0};

        % -------------------- format and check inputs -------------------- %<<<2
        % check number of inputs %<<<3
        if nargin < 2
                print_usage();
        endif
        % format and check input directory %<<<3
        inDir = EnsureProperDirFormat(inDir);
        if exist(inDir, 'dir') ~= 7
                error(['Input directory `' inDir '` not found!'])
        endif
        % format and check start function file name %<<<3
        [di na ex] = fileparts(StartFunction);
        % if start function is only file name:
        if isempty(di)
                % prepend full path to it:
                StartFunction = fullfile(inDir, StartFunction);
        endif
        % check start function existence
        if not(exist(inDir, 'file'))
                error(['Starting function `' StartFunction '` not found!'])
        endif
        StartFunctionFullPath = StartFunction;
        StartFunctionName = na;
        % format and check output graph file name %<<<3
        [di na ex] = fileparts(GraphFile);
        % check proper file:
        if isempty(na)
                error(['Graph file name is empty!'])
        endif
        % if graph is only file name:
        if isempty(di)
                % prepend full path to it:
                GraphFileFullPath = fullfile(inDir, GraphFile);
        else
                GraphFileFullPath = GraphFile;
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
        % remove empty cells:
        Forbidden = Forbidden(not(cellfun('isempty', Forbidden)));
        Settings.Forbidden = Forbidden;
        % format and check variable arguments %<<<3
        [reg, ...
                Settings.GraphType, ...
                Settings.PlotMainFuns, ...
                Settings.PlotSubFuns, ...
                Settings.PlotSpecials, ...
                Settings.PlotOtherFuns, ...
                Settings.PlotOtherUnknownFuns] = parseparams (varargin, ...
                        'graphtype',            'dependency', ...
                        'plotmainfuns',         1,...
                        'plotsubfuns',          1,...
                        'plotspecials',         1,...
                        'plototherfuns',        0,...
                        'plotunknownfuns',      0);

        % -------------------- files parsing -------------------- %<<<2
        disp('Parsing m-files ...')
        % search all .m files in input directory and subdirectories:
        mFilesPathNames = GetAllmFiles(inDir, '.*.m$');
        [tmp1 tmp2 tmp3] = cellfun(@fileparts, mFilesPathNames, 'UniformOutput', false);
        % add all found file names to settings so they can be found even if not called followed by parenthesis
        Settings.mFileNames = tmp2(:);
        % remove empty cells:
        Settings.mFileNames = Settings.mFileNames(not(cellfun('isempty', Settings.mFileNames)));
        % in all m-files find functions and nodes: 
        [Functions Nodes] = cellfun(@GetAllFunDefsAndCalls, mFilesPathNames, {Settings}, 'UniformOutput', 0);
        Nodes = FillInChildrenFunctionField(Functions, Nodes, Settings);
        % now the Functions is cell containing Function structures, one cell per file, and
        % Nodes is cell containing Node structures, one cell per file. Nodes are as found in file, i.e.
        % if something is called multiple times, it is multiple times in Nodes.
        disp(["Files parsed. " num2str(length([Functions{:}])) " function definitions and " num2str(length([Nodes{:}])) " calls (nodes) found in " num2str(length(mFilesPathNames)) " m-files."])

        % -------------------- nodes and functions filtering according settings -------------------- %<<<2
        disp('Filtering results ...')
        % remove forbidden functions and calls from/to forbidden
        Functions = FilterFunctions(Functions, Forbidden);
        Nodes = FilterNodes(Nodes, Forbidden);

        if not(Settings.PlotSpecials)
                % remove special functions and calls from/to specials
                Functions = FilterFunctions(Functions, Settings.Specials);
                Nodes = FilterNodes(Nodes, Settings.Specials);
        endif
        allfuns = [Functions{:}];
        if not(Settings.PlotMainFuns)
                % filter for main functions:
                Filter = unique({allfuns(logical([allfuns.MainFunction])).Name});
                % remove special functions and calls from/to main functions:
                Functions = FilterFunctions(Functions, Filter);
                Nodes = FilterNodes(Nodes, Filter );
        endif
        if not(Settings.PlotSubFuns)
                % filter for sub functions:
                Filter = unique({allfuns(logical([allfuns.SubFunction])).Name});
                % remove special functions and calls from/to sub functions
                Functions = FilterFunctions(Functions, Filter);
                Nodes = FilterNodes(Nodes, Filter );
        endif
        if not(Settings.PlotOtherUnknownFuns)
                % remove other unknown functions and calls from/to other functions
                Nodes = FilterNodesByOtherUnknown(Nodes);
        endif
        if not(Settings.PlotOtherFuns)
                % remove other functions and calls from/to other functions
                Nodes = FilterNodesByOther(Nodes);
        endif
        disp(["Functions and Nodes filtered according settings. " num2str(length([Functions{:}])) " function definitions and " num2str(length([Nodes{:}])) " calls (nodes) left."])

        if isempty([Functions{:}])
                error("No functions left after filtering. Either no functions were found or plotting of all functions was disabled.")
        endif
        if isempty([Nodes{:}])
                error("No nodes left after filtering. Either no nodes were found or plotting of functions related to all nodes was disabled.")
        endif

        % -------------------- dependency graph -------------------- %<<<2
        if strcmpi(Settings.GraphType, 'dependency')
                disp('Reordering for dependency graph ...')
                AllNodes = [Nodes{:}];
                AllFunctions = [Functions{:}];
                % -------------------- nodes processing -------------------- %<<<3
                % all calls of children in one parent (one function) are considered as the same, so for
                % easy deduplication line numbers are removed:
                AllNodes = RemoveLineNo(AllNodes);
                % deduplicate and sort:
                SortedAllNodes = SortNodesByParent(AllNodes);
                % now SortedAllNodes is cell, one cell per function, with unique Nodes.
                % Find first parent - cell with nodes belonging to start function:
                ind = [];
                for j = 1:length(SortedAllNodes)
                        % XXX here should be comparison against filenamepart of StartFunction, but it contains whole path and extension
                        ind(j) = strcmp(StartFunctionName, SortedAllNodes{j}(1).ParentFunction.Name);
                endfor
                if not(any(ind))
                        error(['Starting function `' StartFunctionName '` not found in Sorted Nodes. Check input parameter `StartFunction`.'])
                endif
                id = find(ind);
                if length(id) > 2
                        error('Multiple cells containing the start function were found. Sorting is not working properly. This is internal error.')
                endif
                % prepare recursion:
                % XXX PODIVNA UPRAVA - predtim tohle fungovalo: Parent = SortedAllNodes{id}(1).ParentFunction;
                Parent = [SortedAllNodes{id}](1).ParentFunction;
                Nodes = SortedAllNodes{id};
                WalkList = [{Parent.ID}];
                % start recursion:
                disp('Walking through function calls ...')
                GraphLines = WalkThroughRecursively(Parent, Nodes, WalkList, SortedAllNodes);

        % -------------------- flowchart graph -------------------- %<<<2
        elseif strcmpi(Settings.GraphType, 'flowchart')
                error('not yet implemented')
                % 2DO
        endif

        % -------------------- final graph generation -------------------- %<<<2
        disp('Writing graph ...')
        % join header, graph lines and ending together
        Graph = '/* Generated by mDepGen */';
        Graph = [Graph "\ndigraph dep {\nnode [shape = oval];"];
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
        % filename of graph has to be escaped to process in bash, because dot do not take file names in " "
        cmd = ['dot -Tpdf ' EscapeFileNameForBash(GraphFileFullPath) '.dot -o ' EscapeFileNameForBash(GraphFileFullPath) '.pdf'];
        [STATUS, OUTPUT] = system(cmd);
        if STATUS
                error(["GraphViz failed. Output was:\n" OUTPUT "\nCommand was:\n" cmd])
        else
                disp("Pdf created")
        endif
        disp("Finished")

endfunction % mDepGen

% EnsureProperDirFormat %<<<1
function Dir = EnsureProperDirFormat(Dir)
% Ensures the directory the directory character string ends with a file separator.
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
function [newFunctions newNodes] = GetAllFunDefsAndCalls(FilePathName, Settings)
% In a file, finds all functions defined and all callings of other funtions (Nodes).
% Function have to be defined as `function somefunction(`.
% Called functions must be called as `somefunction(` to be found.
% If called function is listed in Settings.Specials or Settings.Forbidden or Settings., the parenthesis is not required.

        % get name of current m-file:
        [tmp tmp2 tmp3] = fileparts(FilePathName);
        CurFileName = tmp2;

        % prepare structures for easy array building:
        % (this will prevent adding structures into array with different fields)
        newFunctions.Name = '';
        newFunctions.ID = '';
        newFunctions.GraphName = '';
        newFunctions.Special = 0;
        newFunctions.Script = 0;
        newFunctions.MainFunction = 0;
        newFunctions.SubFunction = 0;
        newFunctions.Forbidden = 0;
        newFunctions.Other = 0;
        newFunctions.OtherUnknown = 0;
        newFunctions.FilePathName = '';
        newFunctions.LineNo = 0;

        % following two fields are only temporary and are removed at the end:
        newNodes.ParentFunction = [];
        newNodes.ChildrenFunction = [];
        newNodes.ChildrenFunctionName = [];
        newNodes.LineNo = 0;
        newNodes.FilePathName = '';

        % prepare function definition for the case it is script
        % it will be added to newFunctions only if some call will be found before first function definition in a file
        Script.Name = CurFileName;
        Script.ID = GetFunctionID(CurFileName);
        Script.GraphName = GetFunctionGraphName('', CurFileName, 0);
        Script.Script = 1;
        Script.MainFunction = 0;
        Script.SubFunction = 0;
        Script.Special = any(strcmp(Settings.Specials, Script.Name));
        Script.Forbidden = any(strcmp(Settings.Forbidden, Script.Name));
        Script.Other = 0;
        Script.OtherUnknown = 0;
        Script.FilePathName = FilePathName;
        Script.LineNo = 1; % script starts at first line

        % number of current line in m-file:
        LineNo = 1;
        % if any function in a m-file was already found or not:
        FunctionsFound = 0;
        % name of current function in a m-file:
        CurrentFunctionName = '';
        % variable for second parsing of file to get nodes %<<<2
        % lines of code - do not contain lines with function definition:
        Lines = {};
        % line numbers in original file corresponding to Lines:
        LineNumbers = [];
        % line numbers of function definitions for easy use in second parsing through the file:
        newFunctionsLineNo = [];

        % open the m-file %<<<2
        fid = fopen (FilePathName);
        Line = fgetl (fid);
        % parse line by line and search now only function definitions %<<<2
        while not(feof(fid))
                % strip lines of comments and content inside strings:
                Line = PrepareLine(Line);
                % get function definition
                FunctionDefinitionName = ParseLineGetFunctionDefinitions(Line);
                if ~isempty(FunctionDefinitionName)
                        % function definition found, create new Function structure and set values:
                        newFunction = struct();
                        newFunction.Name = FunctionDefinitionName;
                        newFunction.ID = GetFunctionID(CurFileName, newFunction.Name);
                        newFunction.Script = 0;
                        % first found function is main function:
                        % (this is an assumption!)
                        newFunction.SubFunction = not(not(FunctionsFound));
                        newFunction.MainFunction = not(newFunction.SubFunction);
                        newFunction.GraphName = GetFunctionGraphName(CurFileName, newFunction.Name, newFunction.SubFunction);
                        newFunction.Special = any(strcmp(Settings.Specials, newFunction.Name));
                        newFunction.Forbidden = any(strcmp(Settings.Forbidden, newFunction.Name));
                        newFunction.Other = 0;
                        newFunction.OtherUnknown = newFunction.Other;
                        newFunction.FilePathName = FilePathName;
                        newFunction.LineNo = LineNo;
                        % set flags for next loop iterations:
                        CurrentFunctionName = newFunction.Name;
                        FunctionsFound = FunctionsFound + 1;
                        Line = '';
                        newFunctions = [newFunctions newFunction];
                        newFunctionsLineNo = [newFunctionsLineNo LineNo];
                endif
                if ~isempty(Line)
                        % if Line is not empty, add it to Lines for next loop:
                        Lines{end+1} = Line;
                        LineNumbers(end+1) = LineNo;
                endif
                % for next loop iteration:
                Line = fgetl(fid);
                LineNo = LineNo + 1;
        end
        fclose(fid);
        % remove first empty structure:
        newFunctions(1) = [];

        % searching for nodes %<<<2
        % indicator if file is script:
        isscript = 0;
        % now all subfunctions are known therefore can be identified even if called without parenthesis
        for i = 1:length(Lines)
                % XXX mfilenames are not put into settings and are not found if called without parenthesis!!!!!!
                % get function calls followed by bracket like function(...):
                [Calls1, Lines{i}]= ParseLineGetFunctionCallsWithParenthesis(Lines{i});
                % get function calls of found functions/subfunctions of current file:
                [Calls2, Lines{i}]= ParseLineGetDefinedFunctionCalls(Lines{i}, {newFunctions.Name});
                % get function calls of Specials:
                [Calls3, Lines{i}]= ParseLineGetDefinedFunctionCalls(Lines{i}, Settings.Specials);
                % get function calls of Forbidden:
                [Calls4, Lines{i}]= ParseLineGetDefinedFunctionCalls(Lines{i}, Settings.Forbidden);
                Calls = unique([Calls1 Calls2 Calls3 Calls4]);
                if ~isempty(Calls)
                        % generate nodes from Calls
                        for j = 1:length(Calls)
                                % get parent function name (current line number is LineNumbers(i)):
                                id = find(newFunctionsLineNo < LineNumbers(i));
                                if ~isempty(id)
                                        newNode.ParentFunction = newFunctions(id(end));
                                else
                                        % not yet function definition in m file, it means it is script!
                                        isscript = 1;
                                        newNode.ParentFunction = Script;
                                endif
                                newNode.ChildrenFunction = struct();
                                newNode.ChildrenFunctionName = Calls{j};
                                newNode.LineNo = LineNo;
                                newNode.FilePathName = FilePathName;
                                newNodes = [newNodes newNode];
                        endfor % length(Calls)
                endif % ~isempty(Calls)
        endfor % length(Lines)
        % remove first empty structure:
        newNodes(1) = [];

        % finish for the case of script:
        if isscript
                % set all found functions to subfunctions, fix graph name:
                for i = 1:length(newFunctions)
                        newFunctions(i).MainFunction = 0;
                        newFunctions(i).SubFunction = 1;
                        newFunctions(i).GraphName = GetFunctionGraphName(CurFileName, newFunctions(i).Name, 1);
                endfor
                % add script to newFunctions
                newFunctions(end+1) = Script;
                % set all found functions to subfunctions and fix graph name also in node parents:
                for i = 1:length(newNodes)
                        if newNodes(i).ParentFunction.Script == 0;
                                newNodes(i).ParentFunction.MainFunction = 0;
                                newNodes(i).ParentFunction.SubFunction = 1;
                                newNodes(i).ParentFunction.GraphName = GetFunctionGraphName(CurFileName, newNodes(i).ParentFunction.Name, 1);
                        endif
                endfor % length(newNodes)
        endif  % isscript
endfunction

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

% ParseLineGetFunctionDefinitions %<<<1
function FunctionDefinitionName = ParseLineGetFunctionDefinitions(Line)
% parse line and return function name from function definition if any found
% This can find only one function definition at a line. Assumption!
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
endfunction % ParseLineGetFunctionDefinitions

% ParseLineGetAnyFunctionCalls %<<<1
function [Calls, Line]= ParseLineGetFunctionCallsWithParenthesis(Line)
% parse line and return function names from function calls if any found
% found function calls are replaced by spaces (together with left bracket)
% function has to be in a form:
%   single [a-zA-Z], maybe followed by [a-zA-Z_0-9], maybe followed by spaces, has to be followed by '('
%   the right bracket is not required (multiline statements)
% this finds everything, even something like: variable(5) = 5
        % regular expression:
        Calls = {};
        [S, E, TE, M, T, NM, SP] = regexpi (Line, '([a-zA-Z_][a-zA-Z_0-9]*)\s*\(');
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
        %aaa=f(
        %should not match following:
        %aaa=(iii)
        %aaa=5(iii)
        %>>>2
        if ~isempty(T)
                Calls = T{:};
                % remove match from line:
                for i = 1:length(S)
                        Line(S(i):E(i)) = repmat(' ', 1, E(i)-S(i)+1);
                endfor
        endif
endfunction % ParseLineGetFunctionCallsWithParenthesis

% ParseLineGetDefinedFunctionCalls %<<<1
function [Calls, Line] = ParseLineGetDefinedFunctionCalls(Line, DefinedFunctionNames)
% parse line and return function names from function calls of FunctionNames if any found
% this is to find function calls not followed by parenthesis (like 'disp a' or 'number = some_function_without_parameters')
% however to find it, function has to be known
        % sort DefinedFunctionNames according length from longest to shortest.
        % this is to prevent finding subparts of some defined function name in longer defined function name
        % (like function `some_function` should not be found first in function `some_function_something`)
        len = @cellfun(@length, DefinedFunctionNames);
        [tmp indexes] = sort(len);
        DefinedFunctionNames = DefinedFunctionNames(fliplr(indexes));
        % search line for names:
        Calls = {};
        for i = 1:length(DefinedFunctionNames)
                % XXX find by longest defined function names? how to solve it?
                ids = strfind(Line, DefinedFunctionNames{i});
                if not(isempty(ids))
                        Calls{end+1} = DefinedFunctionNames{i};
                        for j = 1:length(ids)
                                Line(ids(j):ids(j) + length(DefinedFunctionNames{i}) - 1) = repmat(' ', 1, length(DefinedFunctionNames{i}));
                        endfor
                endif
        endfor
endfunction % ParseLineGetDefinedFunctionCalls

% GetFunctionGraphName %<<<1
function GraphName = GetFunctionGraphName(CurFileName, FunctionName, isSubfunction)
% generate name of function as will be shown in graph
        if isSubfunction
                GraphName = [FunctionName '\\n (' CurFileName ')'];
        else
                GraphName = FunctionName;
        endif
endfunction % GetFunctionGraphName

% GetFunctionID %<<<1
function ID = GetFunctionID(FileName, FunctionName='')
% generates unique function identifier from m-file name and function name
% if second field is empty, script is assumed
        if isempty(FunctionName)
                ID = FileName;
        else
                ID = [FileName '>' FunctionName];
        endif
endfunction % GetFunctionID

% WalkThroughRecursively %<<<1
function [GraphLines SortedAllNodesOut] = WalkThroughRecursively(Parent, Nodes, WalkList, SortedAllNodes)
% function walks through functions and prepares graph lines for dependency graph
% function is able to recognize recursions in m-files callings thanks the WalkList
        GraphLines = {};
        % for all nodes/children
        for i=1:length(Nodes)
                disp(['Node ' num2str(i) ' of ' num2str(length(Nodes)) ': ' Parent.ID ' -> ' Nodes(i).ChildrenFunction.ID])
                % check for recursions:
                if any(strcmpi(WalkList, Nodes(i).ChildrenFunction.ID))
                        disp('recursion found')
                        % recursion found, add graph line, do not search for nodes in called function/children:
                        GraphLines(end+1) = MakeDotLine(Parent, Nodes(i).ChildrenFunction, 'recursion');
                        % when recursion, do not continue into deeper level of dependency
                else
                        disp('no recursion, adding graph line')
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
                                disp(['going deeper to ' ParentFunction.ID])
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
                % is it the recursion to itselr?
                if strcmp(Parent.Name, Children.Name)
                        % make arrow pointing down to up
                        app = ' [color=red dir=back];';
                else
                        % this will be probably already correctly plotted by graphviz because it is from lowest level of recursion to beck
                        app = ' [color=red];';
                endif
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

% FillInChildrenFunctionField %<<<1
function Nodes = FillInChildrenFunctionField(Functions, Nodes, Settings)
% adds to nodes a proper value of ChildrenFunction field based on
% found functions and settings. If called function is not in found functions
% or in settings, it is removed!
        AllFunctions = [Functions{:}];
        for i = 1:length(Nodes)
                for j = 1:length(Nodes{i})
                        % get id of Function in the Call
                        id = find( strcmp(Nodes{i}(j).ChildrenFunctionName, {AllFunctions.Name}) );
                        if isempty(id)
                                % call is not a function in list of found functions
                                % create structure of and ad hoc function:
                                newChildren.Name = Nodes{i}(j).ChildrenFunctionName;
                                newChildren.ID = newChildren.Name;
                                newChildren.GraphName = GetFunctionGraphName('', newChildren.Name, 0);
                                newChildren.Special = any(strcmp(newChildren.Name, Settings.Specials));
                                newChildren.Script = 0;
                                newChildren.MainFunction = 1; % this is reasonable assumption!
                                newChildren.SubFunction = 0; % this is reasonable assumption!
                                newChildren.Forbidden = any(strcmp(newChildren.Name, Settings.Forbidden));
                                newChildren.Other = not(newChildren.Special | newChildren.Forbidden);
                                % not only builtin, e.g. parcellfun returns not 5, but 2!
                                newChildren.OtherUnknown = ( newChildren.Other & not(exist(newChildren.Name, 'builtin')) );
                                newChildren.FilePathName = ''; % file path of m-file with this function is unknown
                                newChildren.LineNo = 0; % line number in m-file with definition of this function is unknown
                                % set children function in the Node:
                                % AllNodes(i).CallFunction = tmp;
                                Nodes{i}(j).ChildrenFunction = newChildren;
                        else
                                id = id(1);
                                % set children function in the Node:
                                Nodes{i}(j).ChildrenFunction = AllFunctions(id);
                        endif
                endfor % length(Nodes{i})
        endfor % length(Nodes)
endfunction % FillInChildrenFunctionField

% FilterFunctions %<<<1 
function [Functions Nodes] = FilterFunctions(Functions, Filter);
% removes functions which names are listed in Filter
% preserves cells with arrays of structures
        if ~isempty(Filter)
                for i = 1:length(Functions)
                        % all names of functions as cell of strings:
                        tmp = {[Functions{i}(:)].Name};
                        % first input of strcmp (cell of size 1,1) is the same for all iterations of cellfun
                        % second input of strcmp is changed during cellfun iterations
                        tmp = cellfun(@strcmp, tmp, {Filter}, 'UniformOutput', false);
                        ids = not(sum(vertcat(tmp{:}),2));
                        Functions{i} = Functions{i}(ids);
                endfor
        endif
endfunction % FilterFunctions

% FilterNodes %<<<1
function [Nodes] = FilterNodes(Nodes, Filter);
% removes nodes with parent or children function with names listed in Filter
% preserves cells with arrays of structures
        if ~isempty(Filter)
                for i = 1:length(Nodes)
                        if ~isempty(Nodes{i})
                                % filter by parents %<<<2
                                % all names of parent functions as cell of strings:
                                tmp = {[Nodes{i}(:).ParentFunction].Name};
                                % first input of strcmp (cell of size 1,1) is the same for all iterations of cellfun
                                % second input of strcmp is changed during cellfun iterations
                                tmp = cellfun(@strcmp, tmp, {Filter}, 'UniformOutput', false);
                                ids = not(sum(vertcat(tmp{:}),2));
                                Nodes{i} = Nodes{i}(ids);

                                if ~isempty(Nodes{i})
                                        % filter by children %<<<2
                                        % all names of children functions as cell of strings:
                                        tmp = {[Nodes{i}(:).ChildrenFunction].Name};
                                        % first input of strcmp (cell of size 1,1) is the same for all iterations of cellfun
                                        % second input of strcmp is changed during cellfun iterations
                                        tmp = cellfun(@strcmp, tmp, {Filter}, 'UniformOutput', false);
                                        ids = not(sum(vertcat(tmp{:}),2));
                                        Nodes{i} = Nodes{i}(ids);
                                endif
                        endif % ~iempty(Nodes{i})
                endfor % length(Nodes)
        endif % ~iempty(Filter)
endfunction % FilterNodes

% FilterNodesByOther %<<<1
function [Nodes] = FilterNodesByOther(Nodes);
% removes nodes with other children function
% preserves cells with arrays of structures
        for i = 1:length(Nodes)
                if ~isempty(Nodes{i})
                        % filter by children property .other
                        ids = not([[Nodes{i}(:).ChildrenFunction].Other]);
                        Nodes{i} = Nodes{i}(ids);
                endif % ~isempty(Nodes{i})
        endfor % length(Nodes)
endfunction % FilterNodesByOther

% FilterNodesByOtherUnknown %<<<1
function [Nodes] = FilterNodesByOtherUnknown(Nodes);
% removes nodes with other children function
% preserves cells with arrays of structures
        for i = 1:length(Nodes)
                if ~isempty(Nodes{i})
                        % filter by children property .other
                        ids = not([[Nodes{i}(:).ChildrenFunction].OtherUnknown]);
                        Nodes{i} = Nodes{i}(ids);
                endif % ~isempty(Nodes{i})
        endfor % length(Nodes)
endfunction % FilterNodesByOtherUnknown

% EscapeFileNameForBash %<<<1
function FileName = EscapeFileNameForBash(FileName);
% escapes special characters in FileName for bash processing
        % list of special characters:
        specchars = {char(92), ... % character \, must be first!
                        ' ', '$', "'", '"', '#', '[', ']', '!', '<', '>', '|', ';', '{', '}', '(', ')'};
        for i = 1:length(specchars)
                FileName = strrep(FileName, specchars{i}, [char(92) specchars{i}]);
        endfor
endfunction % EscapeFileNameForBash

% vim modeline: vim: foldmarker=%<<<,%>>> fdm=marker fen ft=octave textwidth=1000
