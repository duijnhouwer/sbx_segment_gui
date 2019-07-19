function x = sbxread(fname,k,N,varargin)

% img = sbxread(fname,k,N,varargin)
%
% Reads from frame k to k+N-1 in file fname
% 
% fname - the file name (e.g., 'xx0_000_001')
% k     - the index of the first frame to be read.  The first index is 0.
% N     - the number of consecutive frames to read starting with k.
%
% If N>1 it returns a 4D array of size = [#pmt rows cols N] 
% If N=1 it returns a 3D array of size = [#pmt rows cols]
%
% #pmts is the number of pmt channels being sampled (1 or 2)
% rows is the number of lines in the image
% cols is the number of pixels in each line
%
%
% The function also creates a global 'info' variable with additional
% informationi about the file

global info_loaded info

% check if already loaded...

if(isempty(info_loaded) || ~strcmp(fname,info_loaded))
    
    if(~isempty(info_loaded))   % try closing previous...
        try
            fclose(info.fid);
        catch
        end
    end

    load(fname);
    
    if(exist([fname ,'.align'])) % aligned?
        info.aligned = load([fname ,'.align'],'-mat');
    else
        info.aligned = [];
    end   
    
    info_loaded = fname;
    
    if(~isfield(info,'sz'))
        sz = [512 796];
    end
    
    if(info.scanmode==0)
        info.recordsPerBuffer = info.recordsPerBuffer*2;
    end
    
    switch info.channels
        case 1
            info.nchan = 2;      % both PMT0 & 1
            factor = 1;
        case 2
            info.nchan = 1;      % PMT 0
            factor = 2;
        case 3
            info.nchan = 1;      % PMT 1
            factor = 2;
    end
       
    SBX=[fname '.sbx'];
    SBXPATH=[fname '_sbxpath.mat'];
    if exist(SBX,'file') && exist(SBXPATH,'file')
        warning('The folder contains both an SBX file\n   ''%s''\nand an SBXPATH file\n   ''%s''.\nIt should contain one or the other, the SBXPATH file is being ignored.',SBX,SBXPATH);
    end
    if ~exist(SBX,'file')
        % There is no SBX file in this folder. The SBX file may be stored
        % elsewhere because the are very big. If that's the case, there
        % should be an SBXPATH file in this folder that contains the path
        % to the SBX file. Let's try that
        errormessage={};
        [~,sbx_fname_stem,ext]=fileparts(SBX);
        sbx_fname_no_path=[sbx_fname_stem ext];
        if ~exist(SBXPATH,'file')
            errormessage{1}=sprintf('There''s no SBX file called ''%s'' in this project folder (%s)',sbx_fname_no_path,fileparts(fname));
            errormessage{3}=sprintf('There''s also no SBXPATH-file called ''%s'' that could contain a link to the SBX-file in a different location.',[sbx_fname_stem '_sbxpath.mat']);
        else
            K=load([fname '_sbxpath.mat']);
            if ~isfield(K,'fullpath_to_sbx')
                errormessage{1}='The SBXPATH file';
                errormessage{2}=['   ' SBXPATH];
                errormessage{3}='is invalid as it does not contain a ''fullpath_to_sbx'' variable';
            end
            SBX=K.fullpath_to_sbx;
            if ~exist(SBX,'file')
                errormessage{1}='The SBXPATH file';
                errormessage{2}=['   ' SBXPATH];
                errormessage{3}='contains a link to a non-existing SBX file:';
                errormessage{4}=['   ' SBX];
            end
        end
        if ~isempty(errormessage)
            locbut=sprintf('Locate %s',sbx_fname_no_path);
            question_str={errormessage{:},'',['Click ''' locbut ''' to search for the file']};
            answer_str=questdlg(question_str,'SBX not found','Cancel',locbut,locbut);
            if strcmpi(answer_str,'Cancel')
                x=[];
                return;
            elseif strcmpi(answer_str,locbut)
                [sbxfile,sbxpath]=uigetfile({'*.sbx','SBX File (*.sbx)'; '*.*','All Files (*.*)'},'Pick a file',sbx_fname_no_path);
                if isnumeric(sbxfile) % user pressed cancel
                    x=[];
                    return;
                else
                    SBX=fullfile(sbxpath,sbxfile);
                    question_str={'Store a link to the external SBX in the project folder for future reference?'};
                    answer_str=questdlg(question_str,'Create SBXPATH file','No','Yes (recommended)','Yes (recommended)');
                    if strcmpi(answer_str,'Yes (recommended)')
                        try
                            fullpath_to_sbx=SBX;
                            save(SBXPATH,'fullpath_to_sbx');
                        catch me
                            warning(me.message);
                        end
                    end
                end
            else
                error('unknown answer');
            end
        end
    end
    
    
    info.fid = fopen(SBX);
    if info.fid==-1
        error([ '[' mfilename '] could not open ' SBX ]);
    end
    d = dir(SBX);
    
    info.nsamples = (info.sz(2) * info.recordsPerBuffer * 2 * info.nchan);   % bytes per record 
    %Edit Patrick: to maintain compatibility with new version
    
    if isfield(info,'scanbox_version') && info.scanbox_version >= 2
        info.max_idx =  d.bytes/info.recordsPerBuffer/info.sz(2)*factor/4 - 1;
        info.nsamples = (info.sz(2) * info.recordsPerBuffer * 2 * info.nchan);   % bytes per record 
    else
        info.max_idx =  d.bytes/info.bytesPerBuffer*factor - 1;
    end
end

if(isfield(info,'fid') && info.fid ~= -1)
    
    % nsamples = info.postTriggerSamples * info.recordsPerBuffer;
        
    try
        fseek(info.fid,k*info.nsamples,'bof');
        x = fread(info.fid,info.nsamples/2 * N,'uint16=>uint16');
        x = reshape(x,[info.nchan info.sz(2) info.recordsPerBuffer  N]);
    catch
        error('Cannot read frame.  Index range likely outside of bounds.');
    end

    x = intmax('uint16')-permute(x,[1 3 2 4]);
    
else
    x = [];
end
