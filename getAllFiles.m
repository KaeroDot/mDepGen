function fileList = getAllFiles(dirName, pattern = '.*') %<<<1
        % function recursively search files in selected directory and subdirectories and returns
        % cell of strings with relative paths and filenames
        % second parameter pattern is REGULAR expression, i.e. all files with .m extension is
        % searched as: '.*.m$'

        dirData = dir(dirName);      %# Get the data for the current directory
        dirIndex = [dirData.isdir];  %# Find the index for directories
        fileList = {dirData(~dirIndex).name}';  %'# Get a list of the files
        if ~isempty(fileList)
                fileList = cellfun(@(x) fullfile(dirName,x),... %# Prepend path to files
                        fileList,'UniformOutput',false);
                matchstart = regexp(fileList, pattern);
                fileList = fileList(~cellfun(@isempty, matchstart));
        endif
        subDirs = {dirData(dirIndex).name};  %# Get a list of the subdirectories
        validIndex = ~ismember(subDirs,{'.','..'});  %# Find index of subdirectories
                                                     %#   that are not '.' or '..'
        for iDir = find(validIndex)                  %# Loop over valid subdirectories
                nextDir = fullfile(dirName,subDirs{iDir});    %# Get the subdirectory path
                fileList = [fileList; getAllFiles(nextDir, pattern)];  %# Recursively call getAllFiles
        endfor
endfunction % getAllFiles

% vim modeline: vim: foldmarker=%<<<,%>>> fdm=marker fen ft=octave textwidth=1000
