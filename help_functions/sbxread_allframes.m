function C=sbxread_allframes(fname,varargin)
    
    % hack to load all frames without knowing the number max number of
    % frames in advance
    %
    % I recommend this be default behavior for sbxread or k and N are
    % ommited or both []. But i don't want to change the sbxread function
    %
    % also, get rid of this idiotic global variable info, it's asking for
    % trouble
    %
    % jacob 20170921
    
    
    global info
    sbxread(fname,0,1,varargin{:}); % fills info
    C=sbxread(fname,0,info.max_idx,varargin{:});
end
