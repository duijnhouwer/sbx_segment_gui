function varargout = sbxsegmentpoly(varargin)
    % SBXSEGMENTPOLY MATLAB code for sbxsegmentpoly.fig
    %      SBXSEGMENTPOLY, by itself, creates a new SBXSEGMENTPOLY or raises the existing
    %      singleton*.
    %
    %      H = SBXSEGMENTPOLY returns the handle to a new SBXSEGMENTPOLY or the handle to
    %      the existing singleton*.
    %
    %      SBXSEGMENTPOLY('CALLBACK',hObject,eventData,handles,...) calls the local
    %      function named CALLBACK in SBXSEGMENTPOLY.M with the given input arguments.
    %
    %      SBXSEGMENTPOLY('Property','Value',...) creates a new SBXSEGMENTPOLY or raises the
    %      existing singleton*.  Starting from the left, property value pairs are
    %      applied to the GUI before sbxsegmentpoly_OpeningFcn gets called.  An
    %      unrecognized property name or invalid value makes property application
    %      stop.  All inputs are passed to sbxsegmentpoly_OpeningFcn via varargin.
    %
    %      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
    %      instance to run (singleton)".
    %x
    % See also: GUIDE, GUIDATA, GUIHANDLES
    
    % Edit the above text to modify the response to help sbxsegmentpoly
    
    % Last Modified by GUIDE v2.5 05-Oct-2018 13:08:58
    
    % Begin initialization code - DO NOT EDIT
    gui_Singleton = 1;
    gui_State = struct('gui_Name',       mfilename, ...
        'gui_Singleton',  gui_Singleton, ...
        'gui_OpeningFcn', @sbxsegmentpoly_OpeningFcn, ...
        'gui_OutputFcn',  @sbxsegmentpoly_OutputFcn, ...
        'gui_LayoutFcn',  [] , ...
        'gui_Callback',   []);
    if nargin && ischar(varargin{1})
        gui_State.gui_Callback = str2func(varargin{1});
    end
    
    
    if nargout
        [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
    else
        gui_mainfcn(gui_State, varargin{:});
    end
    % End initialization code - DO NOT EDIT
    
    
    % --- Executes just before sbxsegmentpoly is made visible.
function sbxsegmentpoly_OpeningFcn(hObject, eventdata, handles, varargin)
    
    % Choose default command line output for sbxsegmentpoly
    handles.output = hObject;
    
    p=inputParser;
    p.addParameter('file','',@ischar);
    p.parse(varargin{:});
    
    % UIWAIT makes sbxsegmentpoly wait for user response (see UIRESUME)
    % uiwait(handles.figure1);
    handles=getFreshGlobals(handles);
    setAllCursorModeRadioButtons(handles,'off');
    guidata(hObject,handles);
    set(handles.figure1,'Units', 'normalized');
    set(handles.figure1,'Position', [0.05 0.2 0.7 0.7]);
    
    % simulate pressing load button in case a filename was provided
    if ~isempty(p.Results.file)
        loadButton_Callback(hObject, p.Results.file, handles)
    end
    
function handles=getFreshGlobals(handles)
    % Add global variables here
    handles.alignFile='';
    handles.segmentFile='';
    handles.image=[]; % the image object
    handles.im_mean=[]; % mean two photon image
    handles.im_sdmean=[];
    handles.im_kurt=[];
    handles.im_corr_eq=[];
    handles.im_mean_eq=[];
    handles.im_sdmean_eq=[];
    handles.im_kurt_eq=[];                
    handles.cellNrMap=[];
    handles.imCellOverlay=[];
    handles.xraypoint = [];
    handles.floodcenter = [];
    handles.floodmap = [];
    handles.floodNrPxDefault=255;
    handles.floodNrPx = handles.floodNrPxDefault; % called npixels in sbxsegmentflood
    if handles.figure1.Name(end)=='*'
        handles.figure1.Name(end)=[]; % no changes to be saved
    end
    
    
    
    % --- Outputs from this function are returned to the command line.
function varargout = sbxsegmentpoly_OutputFcn(hObject, eventdata, handles)
    varargout{1} = handles.output;
    
    
    % --- Executes on button press in loadButton.
function loadButton_Callback(hObject, eventdata, handles)
    if isa(eventdata,'matlab.ui.eventdata.ActionData') % really pressed button
        % Let the user select an ALIGN file to load
        [fn,pathname] = uigetfile('*.align');
        if isequal(fn,0) || isequal(pathname,0)
            return; % user pressed cancel
        end
    elseif ischar(eventdata) % filename was passed
        if exist(eventdata,'file')
            [pathname,fn,~]=fileparts(eventdata);
        else
            msg={['no such file: ' eventdata]};
            uiwait(errordlg(msg,mfilename,'modal'));
            return;
        end
    else
        error(['illegal class for eventdata: ' class(eventdata)]);
    end
    % remove the extension
    [pathname,fn,~]=fileparts(fullfile(pathname,fn));
    %
    cla
    zoom off;
    pan off;
    handles=getFreshGlobals(handles);
    setAllCursorModeRadioButtons(handles,'on');
    set(handles.cursorNormRad,'Value',1);
    handles.alignFile = fullfile(pathname,[fn '.align']);
    if ~exist(handles.alignFile,'file')
        msg={'Could not find the ALIGN file','The correct name would be: ', handles.alignFile};
        uiwait(errordlg(msg,mfilename,'modal'));
        return;
    end
    d=dir(handles.alignFile);
    myPrint(handles,{'Loading',[d.folder filesep],d.name,'...'});
    try
        alignFileData=load(handles.alignFile,'-mat');
    catch me
        myPrint(handles,me.message);
        return
    end
    % generate the filename of the corresponing SEGMENT file, which may
    % already exist
    handles.segmentFile = fullfile(pathname,[fn '.segment']);
    % set this filename in the title bar
    set(handles.figure1,'Name',[mfilename ' - ' handles.segmentFile]);% Set the title of the main window
    axis off
    
    m = double(alignFileData.m);
    m = (m-min(m(:)))/(max(m(:))-min(m(:)));
    handles.im_mean = m;
    clear m;
    
    handles.cellNrMap=zeros(size(handles.im_mean)); % 2D-map containing cellnumbers
    handles.image = imagesc(handles.axes1,repmat(handles.im_mean,[1 1 3])); % allocate the CData which will be overwritten in show soon
    axis(handles.image.Parent,'off');
    
    try
        handles.im_corr = alignFileData.c3;
        g = exp(-(-50:50)/2/8^2);
        g = g/sum(g(:));
        A = convn(convn(handles.im_corr,g,'same'),g','same');
        c3_eq =handles.im_corr./(.01+A);
        handles.im_corr_eq = adapthisteq(c3_eq/max(c3_eq(:)),'NumTiles',[16 16],'Distribution','Exponential');
        
        %Kurtosis
        k = min(max(alignFileData.k,0).^.5,20);
        handles.im_kurt = k/max(k(:));
        
        sm = bsxfun(@times,alignFileData.sm,1./median(alignFileData.sm))-.5;
        handles.im_sdmean = sm/max(sm(:));
        
        A = convn(convn(k,g,'same'),g','same');
        B = conv2(g,g,ones(size(sm)),'same');
        A = A./B;
        A = sqrt(k./(.001+A));
        A = real(A);
        handles.im_kurt_eq = adapthisteq(A/max(A(:)),'NumTiles',[16 16],'Distribution','Exponential');
        
        %Max
        A = conv2(g,g,sm,'same');
        B = conv2(g,g,ones(size(sm)),'same');
        A = A./B;
        A = sm./(.01+A);
        handles.im_sdmean_eq = adapthisteq(A/max(A(:)),'NumTiles',[16 16],'Distribution','Exponential');
        
        set(handles.histeq,'Value',0);
        set(handles.imagemodePanel,'visible','on');
    catch me
        warning(me.message)
    end
    handles.im_mean_eq = adapthisteq(handles.im_mean,'NumTiles',[16 16],'Distribution','Exponential');
    handles.xraypoint = [];
    try
        if isa(alignFileData.xray,'int16')
            alignFileData.xray = single(alignFileData.xray)/2^15;
        end
        handles.xray = alignFileData.xray;
        set(handles.cursorNormRad,'value',1);
    catch
        msg={'No X-ray data found'};
        uiwait(errordlg(msg,mfilename,'modal'));
    end
    set(handles.histeq,'visible','on');
    
    %check if there is a segment file
    if exist(handles.segmentFile,'file')
        d=dir(handles.alignFile);
        myPrint([]);
        pause(1/4);
        myPrint(handles,{'Loading',[d.folder filesep],d.name});
        try
            data=load(handles.segmentFile,'mask','-mat');
            pause(.5);
        catch me
            myPrint(handles,me.message);
            return
        end
        handles.cellNrMap=guaranteeConsecutiveNumberingMask(data.mask);
        % fill the two-photon image's CData matrix
        cNrs=unique(handles.cellNrMap);
        cNrs(cNrs==0)=[]; % remove background number
        for i=1:numel(cNrs)
            cIdx=handles.cellNrMap==i;
            grayChan=handles.image.CData(:,:,1);
            greenChan=grayChan;
            greenChan(cIdx)=brighten(greenChan(cIdx),get(handles.polygonOpacitySlid,'Value'));
            handles.image.CData=cat(3,grayChan,greenChan,grayChan);
        end
    end
    set(handles.image,'ButtonDownFcn',@(x,y)figure1_ButtonDownFcn(x,y,handles));
    guidata(hObject,handles);
    show(hObject,handles);
    axis tight;
    zoom off;
    pan off;
    myPrint([]);
    drawnow;
    axes(handles.axes1); % set focus to 2-photon image
    
    
    % --- Executes on key press with focus on figure1 and none of its controls.
function figure1_KeyPressFcn(hObject, eventdata, handles)
    % eventdata  structure with the following fields (see FIGURE)
    %	Key: name of the key that was pressed, in lower case
    %	Character: character interpretation of the key(s) that was pressed
    %	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
    if nargin==2
        handles=guidata(hObject);
    end
    figure1_WindowKeyPressFcn(hObject, eventdata, handles);
    
    
    
    % --- Executes on key press with focus on figure1 or any of its controls.
function figure1_WindowKeyPressFcn(hObject, eventdata, handles)
    if nargin==2
        handles=guidata(hObject);
    end
    % Disable normal keypresses while getting a polygon. Escape, to cancel
    % the polygon, or Enter, to confirm the edited one, or Delete, to
    % delete it, do work
    
    h=findobj(handles.image.Parent,'Tag','impoly');
    if ~isempty(h)
        if any(strcmpi(eventdata.Key,{'return','escape','delete','backspace'}))
            if strcmpi(eventdata.Key,'return') % confirm the edit
                api=iptgetapi(h);
                % Copy the area of the polygon into cellNrMap
                loc = api.getPosition();
                BW = poly2mask(loc(:,1),loc(:,2),size(handles.image.CData,1), size(handles.image.CData,2));
                handles.cellNrMap(BW)=h.UserData.cellNr;
            elseif strcmpi(eventdata.Key,'escape') % cancel the edit
                handles.cellNrMap(h.UserData.oldIdx)=h.UserData.cellNr;
            end
            delete(h);
            [handles.cellNrMap]=guaranteeConsecutiveNumberingMask(handles.cellNrMap);
            guidata(hObject,handles);
            show(hObject,handles);
        end
    else
        if strcmpi(eventdata.Key,'c') && isempty(eventdata.Modifier)
            if strcmp(handles.cursorPolygonClickRad.Visible,'off')
                return;
            end
            zoom off
            pan off
            set(handles.cursorPolygonClickRad,'Value',1);
            cursorPolygonClickRad_Callback(hObject, eventdata, handles);
        elseif strcmpi(eventdata.Key,'d') && isempty(eventdata.Modifier)
            if strcmp(handles.cursorPolygonDrawRad.Visible,'off')
                return;
            end
            zoom off
            pan off
            set(handles.cursorPolygonDrawRad,'Value',1);
            cursorPolygonDrawRad_Callback(hObject, eventdata, handles);
        elseif strcmpi(eventdata.Key,'f') && isempty(eventdata.Modifier)
            if strcmp(handles.cursorFloodRad.Visible,'off')
                return;
            end
            zoom off
            pan off
            set(handles.cursorFloodRad,'Value',1);
            cursorFloodRad_Callback(hObject, eventdata, handles);
        elseif strcmpi(eventdata.Key,'x') && isempty(eventdata.Modifier)
            if strcmp(handles.cursorXrayRad.Visible,'off')
                return;
            end
            zoom off
            pan off
            set(handles.cursorXrayRad,'Value',1);
            cursorXrayRad_Callback(hObject, eventdata, handles);
        elseif strcmpi(eventdata.Key,'z') && isempty(eventdata.Modifier)
            if strcmp(handles.cursorZoomRad.Visible,'off')
                return;
            end
            zoom off
            pan off
            set(handles.cursorZoomRad,'Value',1);
            cursorZoomRad_Callback(hObject, eventdata, handles);
        elseif strcmpi(eventdata.Key,'h') && isempty(eventdata.Modifier)
            if strcmp(handles.cursorPanRad.Visible,'off')
                return;
            end
            zoom off
            pan off
            set(handles.cursorPanRad,'Value',1);
            cursorPanRad_Callback(hObject, eventdata, handles)
        elseif strcmpi(eventdata.Key,'escape')
            if strcmp(handles.cursorNormRad.Visible,'off')
                return;
            end
            zoom off
            pan off
            set(handles.cursorNormRad,'Value',1);
            cursorNormRad_Callback(hObject, eventdata, handles);
        elseif strcmpi(eventdata.Key,'s') && numel(eventdata.Modifier)==1 && strcmpi(eventdata.Modifier,'control')
            % CTRL-S for quick save
            saveButton_Callback(hObject, eventdata, handles);
        else
            % unhandled keypress
        end
    end
    
    % --- Executes on button press in saveButton.
function saveButton_Callback(hObject, eventdata, handles)
    if isempty(handles.im_mean)
        myPrint(handles,'Nothing to save');
        return;
    end
    [mask,vert]=guaranteeConsecutiveNumberingMask(handles.cellNrMap); %#ok<ASGLU>
    figure1_KeyPressFcn(hObject, struct('Key','escape'), handles); % pretend we press escape to clear things
    d=dir(handles.alignFile);
    myPrint(handles,{['Saving ' num2str(numel(vert)) ' ROIs to '],[d.folder filesep],d.name});
    save(handles.segmentFile,'mask','vert');
    pause(1);
    myPrint([]);
    if handles.figure1.Name(end)=='*'
        handles.figure1.Name(end)=[];
    end
    handles.changesMade=false;
    guidata(hObject,handles);
    
    % --- Executes on button press in pullButton.
function pullButton_Callback(hObject, eventdata, handles)
    if isempty(handles.im_mean)
        myPrint(handles,'Nothing to save and pull');
        return;
    end
    saveButton_Callback(hObject, eventdata, handles);
    d=dir(handles.alignFile);
    myPrint(handles,{'Pulling signals from',[d.folder filesep] ,d.name});
    sbxpullsignals(handles.segmentFile);
    myPrint([]);
    handles.changesMade=false;
    guidata(hObject,handles);
    
    
function [mask,vert]=guaranteeConsecutiveNumberingMask(mask)
    cNrs=unique(mask);
    cNrs(cNrs==0)=[]; % 0 is the background
    if any(diff(cNrs)>1) % true if not all 1 apart
        % update the map to be consecutively numbered. 'unique' sorted them
        % already in ascending order
        for i=1:numel(cNrs)
            mask(mask==cNrs(i))=i;
        end
    end
    if nargout==2
        % optionally get the outlines of the ROIs
        vert=cell(numel(cNrs),1);
        for i=1:numel(cNrs)
            bnds = bwboundaries(mask==i,'noholes');
            vert{i} = fliplr(bnds{1});
        end
    end
 
function axes1_CreateFcn(hObject, eventdata, handles)
    axis off
    
    
function show(hObject,handles,updateAxes)
    if ~exist('updateAxes','var') || isempty(updateAxes)
        updateAxes=true;
    end
    axis(handles.axes1);
    mode = get(handles.imagemodePanel,'SelectedObject');
    mode = get(mode,'Tag');
    if get(handles.histeq,'Value')
        mode=[mode '_eq'];
    end
    try
        switch mode
            case 'rb_corr'
                theim = handles.im_corr;
            case 'rb_m'
                theim = handles.im_mean;
            case 'rb_them'
                theim = handles.im_sdmean;
            case 'rb_k'
                theim = handles.im_kurt;
            case 'rb_corr_eq'
                theim = handles.im_corr_eq;
            case 'rb_m_eq'
                theim = handles.im_mean_eq;
            case 'rb_them_eq'
                theim = handles.im_sdmean_eq;
            case 'rb_k_eq'
                theim = handles.im_kurt_eq;
        end
    catch
        % probably no data loaded yet, nothing to show
        return
    end
    
    % Add the x-ray looking glass to the image
    try
        if ~isempty(handles.xraypoint) && handles.cursorNormRad.Value==0
            sz = size(handles.xray,3);
            thefactor = round(size(theim,2)/size(handles.xray,2));
            handles.xraypoint = max(handles.xraypoint,thefactor/2);
            handles.xraypoint(1) = min(handles.xraypoint(1),size(theim,2));
            handles.xraypoint(2) = min(handles.xraypoint(2),size(theim,1));
            dx = -round(handles.xraypoint(2:-1:1)/thefactor)*thefactor+sz*thefactor/2;
            theim = circshift(theim,dx);
            rg = (1:sz*thefactor);
            R = squeeze(handles.xray(round(handles.xraypoint(2)/thefactor),round(handles.xraypoint(1)/thefactor),:,:));
            A = imresize(R,thefactor);
            R(ceil(end/2),ceil(end/2)) = 0;
            theim(rg,rg) = A/(max(R(:))+.01);
            theim = circshift(theim,-dx);
        end
    catch me
        disp(me.message) % not supposed to ever happen
    end
    
    % Poke the floodfill and ROI into the R and G
    % channels of the RGB microscope image. Stencilled overlays would
    % probably have been a more elegant solution, but this works well.
    opacity=get(handles.polygonOpacitySlid,'Value');
    [R,G]=deal(theim);
    
    % Add the floodfill into B, if floodfill is currently active
    if ~isempty(handles.floodmap)
        floodidx=handles.floodmap<handles.floodNrPx;
        R(floodidx)=min(R(floodidx)+opacity,1);
        G(floodidx)=max(G(floodidx)-opacity,0);
    end
    
    % Add the cell map to the green channel
    G(handles.cellNrMap>0)=min(G(handles.cellNrMap>0)+opacity,1);
    %
    set(handles.image,'CData',cat(3,R,G,theim)); % keep blue channel always as is, no extra info in there, so we can use it as a ground truth. for example used in flooding
    if updateAxes
        axis(handles.image.Parent,'off');
    end
    drawnow
    guidata(hObject,handles);
    updateInfoPanel(handles);
    
    
    % --- Executes on button press in histeq.
function histeq_Callback(hObject, eventdata, handles)
    guidata(hObject,handles);
    show(hObject,handles);
    
    
    
    % --- Executes on mouse motion over figure - except title and menu.
function figure1_WindowButtonMotionFcn(hObject, eventdata, handles)
    if get(handles.cursorXrayRad,'Value')
        a = get(handles.axes1,'CurrentPoint');
        handles.xraypoint = round(a(:,1:2)');
        show(hObject,handles,false);
        guidata(hObject,handles);
    end
    
    % --- Executes on scroll wheel click while the figure is in focus.
function figure1_WindowScrollWheelFcn(hObject, eventdata, handles)
    if ~isempty(handles.floodmap)
        scroll=eventdata.VerticalScrollAmount*eventdata.VerticalScrollCount;
        handles.floodNrPx = max(10,handles.floodNrPx - scroll*15);
        guidata(hObject,handles);
        show(hObject,handles);
    end
    
    
    
    % --- Executes on mouse press over figure background.
function figure1_ButtonDownFcn(hObject, eventdata, ~)
    % This function was the source of a bug that ruined 3 full hours of
    % 5/11/2017. the handles passed to this function is somehow not the same
    % as the other handles. The ROIs array in this handles is always empty,
    % which reset the ROI counter, and ROIs were lost. I don't know why
    % or how this is, but a solution is to get the handles inside hObject and
    % use those. Weird.
    handles=guidata(hObject);
    if get(handles.cursorNormRad,'Value')
        if isempty(handles.cellNrMap)
            return; % no data loaded yet
        end
        a = round(get(handles.axes1,'CurrentPoint'));
        clickX=a(1);
        clickY=a(3);
        if clickX<1 || clickX>size(handles.cellNrMap,2) || clickY<1 || clickY>size(handles.cellNrMap,1)
            % clicked outside window
            return;
        end
        clickedCellNr=handles.cellNrMap(clickY,clickX);
        roi2impoly(hObject, clickedCellNr, handles);
    elseif get(handles.cursorXrayRad,'Value')
        a = get(handles.axes1,'CurrentPoint');
        handles.xraypoint = round(a(:,1:2)');
        show(hObject,handles,false)
        set(handles.cursorNormRad,'Value',1);
        cursorNormRad_Callback(hObject, eventdata, handles)
        guidata(hObject,handles);
    elseif get(handles.cursorFloodRad,'Value')
        if isempty(handles.floodmap)
            % make a new segment using the floodfill technique
            setAllCursorModeRadioButtons(handles,'off');
            set(handles.cursorNormRad,'visible','on');
            set(handles.cursorFloodRad,'visible','on');
            a = get(handles.axes1,'CurrentPoint');
            handles.floodcenter = round(a([1 3]));
            handles.floodmap = computefloodim(handles);
        else
            % close the segment that we're flooding
            floodidx=handles.floodmap<handles.floodNrPx;
            % add the flooridx mask to the cellNrMap
            handles.cellNrMap(floodidx)=max(handles.cellNrMap(:))+1;
            %
            handles.floodcenter = [];
            handles.floodmap = [];
            handles.floodNrPx = handles.floodNrPxDefault;
            setAllCursorModeRadioButtons(handles,'on');
            %
            guidata(hObject,handles);
            set(handles.cursorNormRad,'Value',1);
            cursorNormRad_Callback(hObject, [], handles);
            %
            % Something potentially worth saving now
            if handles.figure1.Name(end)~='*'
                handles.figure1.Name(end+1)='*';
            end
        end
        guidata(hObject,handles);
        show(hObject,handles);
    end
    
    
    
    
function roi2impoly(hObject, eventdata, handles)
    cellNrBeingEdited=eventdata;
    if cellNrBeingEdited==0 || ~isempty(findobj(handles.image.Parent,'Tag','impoly'))
        return;
    end
    %
    setAllCursorModeRadioButtons(handles,'off')
    set(handles.cursorNormRad,'visible','on');
    %
    % convert the patch in the map corresponding to the cell with number
    % "eventdata" to a polygon
    vert = bwboundaries(handles.cellNrMap==cellNrBeingEdited,'noholes');
    vert = fliplr(vert{1});
    if size(vert,1)>15
        % limit to vertices at least N pixels apart
        N=5;
        ok = true(size(vert,1),1);
        start=vert(1,:);
        for i=2:size(vert,1)
            if sqrt(sum((vert(i,:)-start).^2))>N
                start=vert(i,:);
            else
                ok(i)=false;
            end
        end
        vert=vert(ok,:);
    end
    h=impoly(handles.axes1,vert);
    set(h,'UserData',struct('cellNr',cellNrBeingEdited,'oldIdx',find(handles.cellNrMap==cellNrBeingEdited)));
    handles.cellNrMap(handles.cellNrMap==cellNrBeingEdited)=0; % remove from current map
    guidata(hObject,handles);
    show(hObject,handles);
    h.wait();
    figure1_KeyPressFcn(hObject, struct('Key','escape'), handles);
    
    
    
    
    % --- Executes when selected object is changed in imagemodePanel.
function imagemodePanel_SelectionChangeFcn(hObject, eventdata, handles)
    guidata(hObject,handles);
    show(hObject,handles)
    
    
    % --- Executes when selected object is changed in imagemodePanel.
function cursormodePanel_SelectionChangeFcn(hObject, eventdata, handles)
    zoom off
    pan off
    
    
function cursorNormRad_Callback(hObject, eventdata, handles)
    set(handles.figure1, 'Pointer', 'arrow');
    setAllCursorModeRadioButtons(handles,'on');
    if ~isempty(handles.floodmap)
        % user cancels flood by pressing escape or pressing normal cursor
        % radio button
        handles.floodcenter = [];
        handles.floodmap = [];
        handles.floodNrPx = handles.floodNrPxDefault;
        guidata(hObject, handles)
        show(hObject,handles);
    end

function cursorPanRad_Callback(hObject, eventdata, handles)
    pan on
    window_keypress_panzoom_fix(hObject, eventdata, handles);
    
function cursorZoomRad_Callback(hObject, eventdata, handles)
    zoom on
    window_keypress_panzoom_fix(hObject, eventdata, handles);
    
    % --- Executes on button press in cursorFloodRad.
function cursorFloodRad_Callback(hObject, eventdata, handles)
    set(handles.cursorZoomRad,'visible','off');
    set(handles.cursorPanRad,'visible','off');
    set(handles.cursorXrayRad,'visible','off');
    set(handles.cursorPolygonClickRad,'visible','off');
    set(handles.cursorPolygonDrawRad,'visible','off');
    set(handles.figure1, 'Pointer', 'fleur');
    % set(handles.cursorFloodRad,'visible','off');
    
function cursorXrayRad_Callback(hObject, eventdata, handles)
    handles.xraypoint = [];
    set(handles.figure1, 'Pointer', 'circle');
    guidata(hObject,handles);
    show(hObject,handles);
    
function cursorPolygonDrawRad_Callback(hObject, eventdata, handles)
    userCreatePolygon(hObject, 'freehand', handles)
    
function cursorPolygonClickRad_Callback(hObject, eventdata, handles)
    userCreatePolygon(hObject, 'click', handles)
    
function userCreatePolygon(hObject, eventdata, handles)
    if ~isempty(findobj(handles.image.Parent,'Tag','impoly'))
        return;
    end
    set(handles.cursorZoomRad,'visible','off');
    set(handles.cursorPanRad,'visible','off');
    set(handles.cursorXrayRad,'visible','off');
    set(handles.cursorPolygonClickRad,'visible','off');
    set(handles.cursorPolygonDrawRad,'visible','off');
    set(handles.cursorFloodRad,'visible','off');
    if strcmpi(eventdata,'freehand')
        h = imfreehand(handles.axes1);
    elseif strcmpi(eventdata,'click')
        h = impoly(handles.axes1);
    else
        error('Unknown polygon input method');
    end
    set(handles.cursorZoomRad,'visible','on');
    set(handles.cursorPanRad,'visible','on');
    set(handles.cursorXrayRad,'visible','on');
    set(handles.cursorPolygonClickRad,'visible','on');
    set(handles.cursorPolygonDrawRad,'visible','on');
    set(handles.cursorFloodRad,'visible','on');
    if isempty(h) || ~h.isvalid() % empty when polygon selection canceled by pressing escape
        return;
    end
    % Add the ROI to the cellNrMap
    loc = h.getPosition;
    h.delete();
    nVertices=size(loc,1);
    if nVertices<3
        % not a valid polygon, ignore
    else
        % Copy the area of the polygon into the internal cellNrMap
        BW = poly2mask(loc(:,1),loc(:,2),size(handles.image.CData,1), size(handles.image.CData,2));
        butName=categorical({'OK'});
        if sum(BW(:))<20
            msg{1}=sprintf('The ROI you created only contains %d pixels.',sum(BW(:)));
            msg{2}='Add it to the list of ROIs?';
            butName = categorical(cellstr(questdlg(msg,mfilename,'Cancel','OK','OK')));
        end
        if butName=='OK'
            handles.cellNrMap(BW)=max(handles.cellNrMap(:))+1;
            handles.cellNrMap=guaranteeConsecutiveNumberingMask(handles.cellNrMap);
            % Something potentially worth saving now
            if handles.figure1.Name(end)~='*'
                handles.figure1.Name(end+1)='*';
            end
        end
    end
    % after polygon is completed (or canceled with escape), switch on normal
    % cursor (automomatically switches off the polygon-radio buttion because in
    % a radiobutton panel)
    set(handles.cursorNormRad,'Value',1);
    guidata(hObject,handles);
    show(hObject,handles);
    
    
    
function buttonPanel_SizeChangedFcn(hObject, eventdata, handles)
    
    % --- Executes when figure1 is resized.
function figure1_SizeChangedFcn(hObject, eventdata, handles)
    % rescale the image (axes1) so it has maximum surface
    handles.figure1.Units='pixels';
    handles.axis1.Units='pixels';
    handles.imagemodePanel.Units='pixels';
    handles.viewPanel.Units='pixels';
    handles.buttonPanel.Units='pixels';
    guiWidPx=handles.figure1.Position(3);
    guiHeiPx=handles.figure1.Position(4);
    margPx=4; % for aesthetics
    handles.buttonPanel.Position(1)=margPx;
    handles.imagemodePanel.Position(1)=margPx;
    handles.viewPanel.Position(1)=margPx;
    handles.infoPanel.Position(1)=margPx;
    handles.buttonPanel.Position(3)=handles.imagemodePanel.Position(3); % set width
    handles.viewPanel.Position(3)=handles.imagemodePanel.Position(3); % set width
    handles.infoPanel.Position(3)=handles.imagemodePanel.Position(3); % set width
    ctrlPx=sum(handles.imagemodePanel.Position([1 3])); % lefthandControlsWidthPx
    handles.axes1.Position=[ctrlPx+margPx margPx guiWidPx-ctrlPx-2*margPx guiHeiPx-2*margPx];
    handles.buttonPanel.Position(2)=guiHeiPx-handles.buttonPanel.Position(4)-margPx;
    handles.imagemodePanel.Position(2)=handles.buttonPanel.Position(2)-handles.imagemodePanel.Position(4)-margPx;
    handles.viewPanel.Position(2)=handles.imagemodePanel.Position(2)-handles.viewPanel.Position(4)-margPx;
    handles.infoPanel.Position(2)=handles.viewPanel.Position(2)-handles.infoPanel.Position(4)-margPx;
    
    
function myPrint(handles,str)
    % string can be a cell array of strings, each cell a line
    if nargin==1, str=[]; end
    persistent hStr
    if ~isempty(hStr)
        delete(hStr);
    end
    if ~isempty(handles) && ~isempty(str)
        hStr=text(0.5,0.5,str,'Unit','normalized','FontSize',12,'HorizontalAlignment','center','Interpreter','none','Color','k','BackGroundColor',[1 .85 1 .67],'Parent',handles.axes1);
    end
    drawnow
    
function updateInfoPanel(handles)
    color='k';
    str={};
    str{end+1}=['N = ' num2str(max(handles.cellNrMap(:))+1)];
    str{end+1}='';
    h=findobj(handles.image.Parent,'Tag','impoly');
    if ~isempty(h)
        str{end+1}=['Editing ROI ' num2str(h.UserData.cellNr,'%.3d')];
        str{end+1}='';
        str{end+1}='[RET] confirm';
        str{end+1}='[DEL] delete';
        str{end+1}='[ESC] cancel';
    elseif ~isempty(handles.floodmap)
        str{end+1}='Scrollwheel adjusts flood threshold.';
        str{end+1}='';
        str{end+1}='Left click to accept.';
        str{end+1}='';
        str{end+1}='ESC to cancel.';
    end
    set(handles.infoField,'String',str,'ForegroundColor',color);
    
    
function window_keypress_panzoom_fix(hObject, eventdata, handles)
    % This fix re-enables capture of in-window keypresses in pan or zoom mode.
    % It makes use of an undocumented MATLAB feature that was changed in R2014b.
    % This approach may even work in datatip mode; but I haven't tested that. It
    % is based on Yair Altman's writeup on the following webpage. (DJL)
    %
    % http://undocumentedmatlab.com/blog/enabling-user-callbacks-during-zoom-pan
    % FIXME - uigetmodemanager is undocumented (DJL)
    hManager = uigetmodemanager(handles.figure1);
    if verLessThan('matlab', '8.4')
        % this should work for versions of MATLAB <= R2014a
        set(hManager.WindowListenerHandles, 'Enable', 'off');
    else
        % this works in R2014b, and maybe beyond; your mileage may vary
        [hManager.WindowListenerHandles.Enabled] = deal(false);
    end
    % these lines are common to all versions up to R2014b (and maybe beyond)
    set(handles.figure1,'WindowKeyPressFcn',[]);
    set(handles.figure1,'KeyPressFcn',@figure1_KeyPressFcn);
    
    
    
    % --- Executes on button press in lockAspectRatioCb.
function lockAspectRatioCb_Callback(hObject, eventdata, handles)
    if get(handles.lockAspectRatioCb,'Value')
        axis(handles.axes1,'equal');
    else
        axis(handles.axes1,'normal');
    end
    
    
    % --- Executes on slider movement.
function polygonOpacitySlid_Callback(hObject, eventdata, handles)
    sat=get(handles.polygonOpacitySlid,'Value');
    if sat==0
        set(hObject,'BackgroundColor',[1 0 0]); % alert user the slider is all the way off
    else
        set(hObject,'BackgroundColor',[.9-sat*.9 .9+sat/10 0.9-sat*.9]);
    end
    show(hObject,handles); % update the opacity of the ROIs in the 2-photon image
    
    
    
    % --- Executes during object creation, after setting all properties.
function polygonOpacitySlid_CreateFcn(hObject, eventdata, handles)
    sat=get(hObject,'Value');
    if sat==0
        set(hObject,'BackgroundColor',[1 0 0]); % alert user the slider is all the way off
    else
        set(hObject,'BackgroundColor',[.9-sat*.9 .9+sat/10 0.9-sat*.9]);
    end
    
    
function B = computefloodim(handles)
    im = get(handles.image,'CData');
    im = im(:,:,3);
    % limit to square around the click (block out rest with zeros)
    fx = round(handles.floodcenter(1));
    fy = round(handles.floodcenter(2));
    xRayWid=size(handles.xray,3);
    xRayHei=size(handles.xray,4);
    minx=max(1,fx-xRayWid);
    maxx=min(size(im,2),fx+xRayWid);
    miny=max(1,fy-xRayHei);
    maxy=min(size(im,1),fy+xRayHei);
    im(:,[1:minx maxx:end])=0;
    im([1:miny maxy:end],:)=0;
    % block out already selected cells with zeros too
    im = im.*(handles.cellNrMap==0);
    % use external function to find a threshold map for flood fill
    [~,B] = regiongrowing(im,fy,fx,nnz(im(:))); % fy and fx order: sic
    
function setAllCursorModeRadioButtons(handles,mode)
    % hide or show all the radion buttons in the cursor mode panel
    fn=fieldnames(handles);
    for i=1:numel(fn)
        if strncmp(fn{i},'cursor',6)
            set(handles.(fn{i}),'visible',mode);
        end
    end
    
    % --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
    if handles.figure1.Name(end)=='*'
        msg{1}='Save the changes you made?';
        butName = categorical(cellstr(questdlg(msg,mfilename, 'Cancel','Discard','Save','Save')));
        if butName=='Save'
            saveButton_Callback(hObject, eventdata, handles);
            delete(hObject);
        elseif  butName=='Discard'
            delete(hObject);
        elseif butName=='Cancel'
            return
        end
    else
        delete(hObject);
        return;
    end
    

