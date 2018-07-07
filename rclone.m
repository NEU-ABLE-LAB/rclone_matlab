function [status,cmdout,varargout] = rclone(cmdFmt,varargin)
%RCLONE wrapper for the rclone executable. https://rclone.org/
%
% [status,cmdout] = rclone(cmdFmt,A1,...,An) executes the rclone command
% 'rclone cmd' returning a status in and cmdout string. The data in arrays
% A1,...,An will be formatted acording to the format specification in cmd
% in column order.
%
%   The rclone output is echoed to the Matlab command window when the
%   verbose flag is present, e.g. `-v`. Otherwise the output is returned as
%   cmdout.
% 
% [___] = rclone(___,'warn',errID) Throws a warning for the specified
% error instead of an error. For multiple errIDs, use a cell array.
%
% [___,files] = rclone('copy ___',___) Returns a structure with following
% fields indicating which files were copied
%
%   .new - A new file was copied from the source to dest
%
%   .updated - A updated file from the source was copied to the dest
%
%   .dry - Dry run. These files would have been copied without the
%   `--dry-run` flag.
%
%   A verbose flag is always added when using the rclone copy command to
%   see the files that are copied. If a verbose flag was not provided, then
%   the rclone output is not echoed when the verbose flag is added.
%
% [___,hashes] = rclone('md5sum ___',___) Produces an md5sum file for all
% the objects in the path. This is in the same format as the standard
% md5sum tool produces. Returns a map with full path filenames as keys and
% hashes as values
%
%   The rclone verbose flag, e.g., `-v` is removed when using the md5sum
%   command since the verbose output may mess up the output processing.
%
% [___,jsonout] = rclone('lsjson ___',___) List directories and objects in
% the path in JSON format decoded as a structure.
%
%    See also SPRINTF.

%TODO check if rclone is found
%TODO handle quoted strings

%% Input parsing
% Parse error to warning conversions
if nargin>2 && strcmpi(varargin{end-1},'warn') && ...
        (iscell(varargin{end}) || ischar(varargin{end}) || ...
        isstring(varargin{end}))
    if ischar(varargin{end})
        warnID = {varargin{end}};
    else
        warnID = varargin{end};
    end
    varargin = varargin(1:end-2);
else
    warnID = {};
end

% Verbose flag
if any(cellfun(@(x)(~isempty(x)),regexp(varargin,'(^|\s)-[vV]+($|\s)')))
    verbose = true;
else
    verbose = false;
end

% Compile command
[cmdStr, errmsg] = sprintf(['rclone ' cmdFmt], varargin{:});
if ~isempty(errmsg)
    warning('rclone:sprintf','Error in formatSpec');
end

% Find base rclone command, e.g. 'copy.
tokens = regexpi(cmdStr,'^rclone ([a-z0-9]+)','tokens');
if length(tokens)==1 && length(tokens{1})==1
    cmdBase = tokens{1}{1};
else
    cmdBase = '';
end

% Special command input processing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
switch cmdBase
    case 'copy'
        % COPY command
        % Set verbose flag to output which files have been copied
        if ~verbose
            cmdStr = [cmdStr ' -v'];
        end
    
    case 'md5sum'
        % MD5SUM command
        % Remove rclone verbose flag since it messes with output
        cmdStr = regexprep(cmdStr,'(\s)-v+?\>','$1');
end



%% Run clone command
% If verbose flag is present, then echo system command
if verbose
    disp(cmdStr);
    [status,cmdout] = system(cmdStr,'-echo');
    %TODO The verbose flag messes with output parsing below
else
    [status,cmdout] = system(cmdStr);
end

%% Error checking
% Check status
if status
    switch status
        case 1 % Syntax or usage error
            errID = 'rclone:syntax';
        case 2 % Error not otherwise categorised
            errID = 'rclone:other';
        case 3 % Directory not found
            errID = 'rclone:dirNF';
        case 4 % File not found
            errID = 'rclone:fileNF';
        case 5 % Temporary error (one that more retries might fix) (Retry errors)
            errID = 'rclone:retry';
        case 6 % Less serious errors (like 461 errors from dropbox) (NoRetry errors)
            errID = 'rclone:noRetry';
        case 7 % Fatal error (one that more retries won't fix, like account suspended) (Fatal errors)
            errID = 'rclone:fatal';
        case 8 % Transfer exceeded - limit set by --max-transfer reached
            errID = 'rclone:maxTransfer';
        otherwise
            errID = 'rclone:unknown';
    end
    if strcmpi(errID, warnID)
        % Warn about rclone error
        warning(errID, ['rclone error. \n'...
                'The rclone cmd:\n' ...
                '%s\n' ...
                'returned:\n' ...
                '%s\n'], ...
            cmdStr, cmdout);
    else
        % Throw rclone error
        error(errID, ['rclone error. \n'...
                'The rclone cmd:\n' ...
                '%s\n' ...
                'returned:\n' ...
                '%s\n'], ...
            cmdStr, cmdout);
    end
else
    errID = '';
end

%% Special output parsing
% regex for datetime string YYYY/mm/dd HH:MM:SS
regexTS = ...
    '[0-9]{4}\/[0-9]{2}\/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}';

% regex for path to file with extension. 
%   / - directory separator
%   a-z, 0-9, _-<space> - valid path characters
%   . - extension separator
%   a-z, 0-9 - valid extension characters. Starts with a-z
regexPath = ...
    '[a-z_\-\s0-9\.^:\/]+?\.[a-z0-9]+';
        
switch cmdBase
    case 'copy'
        % 'copy' -- Returns copied files
        
        % Extract new copied files from cmdout
        names = regexpi(cmdout,...
            [regexTS ' INFO  : (?<path>' regexPath ...
                '): Copied \(new\)'],...
            'names');
        files.new = {names.path};
        
        % Extract updated copied files from cmdout
        names = regexpi(cmdout,...
            [regexTS  ' INFO  : (?<path>' regexPath ...
                '): Copied \(replaced existing\)'],...
            'names');
        files.updated = {names.path};
        
        % Extract files copied except for dry run
        names = regexpi(cmdout,...
            ['^' regexTS  ' NOTICE: (?<path>' regexPath ...
                '): Not copying as --dry-run$'],...
            'lineanchors', ...
            'names');
        files.dry = {names.path};
        
        varargout{1} = files;
    
    case 'md5sum'
        % 'md5sum' -- Return checksums as map.

        if isempty(cmdout)
            % Create map with filenames as keys and hashes as values
            varargout{1} = containers.Map();
            return
        end

        % rclone returns a row for each file starting with the checksum, 
        % followed by two spaces, then the filename. The whole this is padded 
        % by an extra line.    
        regexHash = '[a-f0-9]{32}'; % Regex for valid md5 hash
        names = regexpi(cmdout, ...
            ['(?<hashes>' regexHash ')  (?<fNames>' regexPath '$)'],...
            'lineanchors','names');
        fNames = {names.fNames};
        hashes = {names.hashes};
        
        % The filenames of 'rclone md5sum' are relative to the path given,
        % if a directory is given as the path. If a file is given as a
        % path, then the file name is returned.

        % Extract path from command
        path = regexp(cmdStr, 'rclone md5sum (\S*)','tokens');
        if ~iscell(path) && length(path)~=1 && length(path{1})~=1
            error('Unexpected results from regexp while extracting path');
        end
        path = path{1}{1};

        % Determine if path given to 'rclone md5sum' was a path or a file based
        % on if the string ends with '/' or '.\w*' repectively
        if regexp(path,'/$') % path is a directory
            % Do nothing
        elseif regexp(path, '\.\w*$') % path is a file
            path = regexp(path,'(.*/)[\S^]*\.\w*$','tokens');
            if  ~iscell(path) && length(path)~=1 && length(path{1})~=1
                error('Unexpected results from regexp while extracting path');
            end
            path = path{1}{1}; 
        else
            error('Path "%s%" not recognized as directory or file', path);
        end

        % Add full path back to fNames
        fNames = cellfun(@(x)([path x]), fNames, 'UniformOutput',false);

        % Create map with filenames as keys and hashes as values
        varargout{1} = containers.Map( fNames, hashes );
    
    case 'lsjson'
        % 'lsjson' -- Return decoded json
        if strcmpi(errID,'rclone:dirNF')
            varargout{1} = [];
        else
            varargout{1} = jsondecode(cmdout);
        end
end
end % function rclone
