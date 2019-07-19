function varargout = sbxcelltype(varargin)
    
    % SBXCELLTYPE MATLAB code for sbxcelltype.fig
    %   see also: sbxsegmentpoly.
    %
    %   Jacob Duijnhouwer 20171016
    
    gui_Singleton = 1;
    gui_State = struct('gui_Name',       mfilename, ...
        'gui_Singleton',  gui_Singleton, ...
        'gui_OpeningFcn', @sbxcelltype_OpeningFcn, ...
        'gui_OutputFcn',  @sbxcelltype_OutputFcn, ...
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
    
function state=BUSY(update)
    % BUSY used to be a global variable but that could spill over files and
    % instances. Now it's a function.
    persistent B
    if isempty(B)
        B=false;
    end
    if nargin==1
        if ~islogical(update)
            error('BUSY state must be logical');
        end
        B=update;
    end
    state=B; % "The PERSISTENT declaration must precede any use of the variable B" hence function can't output B directly ...
    
    
    % --- Executes just before sbxcelltype is made visible.
function sbxcelltype_OpeningFcn(hObject, eventdata, handles, varargin)
    % This function has no output args, see OutputFcn.
    % Choose default command line output for sbxcelltype
    handles.output = hObject;
    % global variables here
    handles=getFreshGlobals(hObject,handles);
    handles.figure1.Color=[.94 .94 .94];
    % hint:
    myPrint(handles,'Choose ''Help>Getting started'' for instructions');
    % Update handles structure
    guidata(hObject, handles);
    displayMaps(hObject,handles)
    
    
function  handles=getFreshGlobals(hObject,handles)
    handles.image=[];
    handles.pmt0map=[];
    handles.pmt0map_enhanced=[];
    handles.pmt1map=[];
    handles.pmtShiftPx=struct('x',0,'y',0);
    handles.roimap=[];
    handles.cNrs=[];
    handles.outlines=[];
    handles.centroids=[];
    handles.roiboxes=[];
    handles.pmt01fname='';
    handles.segmentFilename='';
    handles.sbxsegmentpolyGui=[];
    handles.cellType=[];
    handles.confidenceStars=[];
    handles.zoom=[];
    handles.slideshow_cNrs=[];
    handles.slideshow_cNrs_done=[];
    handles.cellTypesToHighlight=categorical({''});
    % set default labels
    handles.category_labels=categorical({'GABA','Non-GABA','',''});
    for i=1:numel(handles.category_labels)
        fieldname=sprintf('editLabel%d',i);
        handles.(fieldname).String=char(handles.category_labels(i));
    end
    % Clear axes too
    cla(handles.axes1);
    set(handles.axes1,'Ytick',[],'Xtick',[]);
    %
    buttonDefaultPmt0Enhance_Callback(hObject, 'ALL', handles); % reset enhancements
    handles.button_startstopslideshow.String='Start'; % related to zoom, slideshow_cNrs
    % set(handles.panel_categories,'Visible','on');
    handles.sliderPmtZeroOpacity.Value=1;
    handles.sliderPmtOneOpacity.Value=1;
    handles.sliderSegmentOpacity.Value=1;
    handles.checkHideOverlay.Value=false;
    %
    BUSY(false); % override, set to non-busy
    myPrint(handles); % clean any message that might be displayed
    set(handles.figure1,'Name',mfilename);
    %
    guidata(hObject, handles);
    
function displayMaps(hObject,handles)
    if isempty(handles.pmt0map)
        return;
    end
    try
        BUSY(true);
        R=padshift(handles.pmt0map_enhanced,handles.pmtShiftPx.x,handles.pmtShiftPx.y);
        G=padshift(handles.pmt1map,handles.pmtShiftPx.x,handles.pmtShiftPx.y);
        R=R*handles.sliderPmtZeroOpacity.Value;
        G=G*handles.sliderPmtOneOpacity.Value;
        if ~isempty(handles.zoom)
            theOneCell=handles.zoom.cNr;
        else
            theOneCell=[];
        end
        if ~isempty(handles.outlines) && handles.sliderSegmentOpacity.Value>0 && ~handles.checkHideOverlay.Value
            % Make the Blue|Cyan ROI overlay
            handles=guidata(hObject);
            if ~isempty(theOneCell)
                B=double(handles.outlines==theOneCell)*handles.sliderSegmentOpacity.Value;
            else
                B=double(handles.outlines>0)*handles.sliderSegmentOpacity.Value;
            end
            Goutline=G;
            if ~isempty(theOneCell)
                range=find(handles.cNrs==theOneCell);
            else
                range=1:numel(handles.cNrs);
            end
            for i=range(:)'
                if any(handles.cellType(i)==handles.cellTypesToHighlight)
                    Goutline(handles.outlines==handles.cNrs(i))=handles.sliderSegmentOpacity.Value;
                end
                if handles.cellType(i)~='unlabeled'
                    % mark ROIs that have been labeled with a dot
                    x=min(max(1,ceil(handles.centroids(i,1))+[0 1]),size(G,2));
                    y=min(max(1,ceil(handles.centroids(i,2))+[0 1]),size(G,1));
                    B(y,x)=handles.sliderSegmentOpacity.Value;
                    if any(handles.cellType(i)==handles.cellTypesToHighlight)
                        G(y,x)=handles.sliderSegmentOpacity.Value;
                    end
                end
            end
            % don't let black rings develop with low overlay opacity
            G=max(G,Goutline);
        else
            B=zeros(size(G));
        end
        if ~isempty(handles.zoom)
            minx=ceil(max(1, handles.zoom.center(1)-handles.zoom.wid/2));
            miny=ceil(max(1, handles.zoom.center(2)-handles.zoom.hei/2));
            maxx=ceil(min(minx+handles.zoom.wid, size(handles.pmt0map,2)));
            maxy=ceil(min(miny+handles.zoom.hei, size(handles.pmt0map,1)));
            R=R(miny:maxy,minx:maxx);
            G=G(miny:maxy,minx:maxx);
            B=B(miny:maxy,minx:maxx);
        end
        if ~isempty(handles.zoom)
            R=R-min(R(:));
            R=R/max(R(:));
        end
        handles.image=imagesc(handles.axes1,cat(3,R,G,B));
        if ~isempty(handles.roimap)
            % Attach a button down function to detect mouse clicks in the image
            set(handles.image,'ButtonDownFcn',@(x,y)image_ButtonDownFcn(x,y,handles));
            c = uicontextmenu;% Create a placeholder uicontextmenu
            handles.image.UIContextMenu = c; % Assign the uicontextmenu to the image
        end
        if ~isempty(handles.slideshow_cNrs)
            msg{1}=sprintf('Cell %d (%d remain)',handles.slideshow_cNrs(end),numel(handles.slideshow_cNrs));
            str='';
            for i=1:numel(handles.category_labels)
                if ~isundefined(handles.category_labels(i))
                    str=[str sprintf('%d: %s ',i,handles.category_labels(i))]; %#ok<AGROW>
                end
            end
            msg{end+1}=[str 'U: Unlabel'];
            msg{end+1}='Hold ALT with the above options to indicate HIGH confidence';
            if ~isempty(handles.slideshow_cNrs_done)
                msg{end+1}='B: Back, S: Skip, Esc: Quit';
            else
                msg{end+1}='S: Skip, Esc: Quit';
            end
            if handles.zoom.wid>10 && handles.zoom.wid<size(handles.roimap,2)
                msg{end+1}='+: Zoom in, -: Zoom out';
            elseif handles.zoom.wid>=size(handles.roimap,2)
                msg{end+1}='+: Zoom in';
            elseif handles.zoom.wid<=10
                msg{end+1}='-: Zoom out';
            end
            text(handles.axes1,.02,.89,msg,'Units','Normalized','FontSize',12,'Color','w');
        end
        % remote the x and y ticks and labels
        set(handles.axes1,'Ytick',[],'Xtick',[]);
        %
        BUSY(false);
    catch me
        BUSY(false);
        rethrow(me);
    end
    
    
    % --- Outputs from this function are returned to the command line.
function varargout = sbxcelltype_OutputFcn(hObject, eventdata, handles)
    % Get default command line output from handles structure
    varargout{1} = handles.output;
    
    
    % --- Executes on button press in buttonShiftZero.
function buttonShift_Callback(hObject, eventdata, handles)
    if BUSY || isempty(handles.pmt0map)
        return;
    end
    if ~isempty(handles.slideshow_cNrs)
        msg={'Image shift not allowed in 2AFC mode'};
        uiwait(errordlg(msg,mfilename,'modal'));
        return;
    end
    if hObject.String(1)=='<'
        handles.pmtShiftPx.x=handles.pmtShiftPx.x-1;
    elseif hObject.String(1)=='>'
        handles.pmtShiftPx.x=handles.pmtShiftPx.x+1;
    elseif hObject.String(1)=='/' % '/\'
        handles.pmtShiftPx.y=handles.pmtShiftPx.y-1;
    elseif hObject.String(1)=='\' % '\/'
        handles.pmtShiftPx.y=handles.pmtShiftPx.y+1;
    elseif hObject.String(1)=='0'
        handles.pmtShiftPx=struct('x',0,'y',0);
    end
    displayMaps(hObject,handles);
    guidata(hObject, handles);
    
    
    % --- Executes on slider movement.
function sliderOpacity_Callback(hObject, eventdata, handles)
    if BUSY
        return;
    end
    displayMaps(hObject,handles);
    guidata(hObject, handles);
    
    
    
function retval=checkDataLoaded(hObject, handles)
    retval=0;
    msg={};
    if isempty(handles.pmt0map)
        retval=retval+1;
        msg{end+1}='PMT0+1 file not loaded';
    end
    if isempty(handles.roimap)
        retval=retval+2;
        msg{end+1}='SEGMENT file not loaded';
    end
    if ~isempty(msg)
        uiwait(errordlg(msg,mfilename,'modal'));
        return;
    end
    
    % --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
    handles=getFreshGlobals(hObject,handles);
    delete(hObject);
    
function menu_file_quit_Callback(hObject, eventdata, handles)
    figure1_CloseRequestFcn(handles.figure1, eventdata, handles)
    
    % --- Executes on key press with focus on figure1 or any of its controls.
function figure1_WindowKeyPressFcn(hObject, eventdata, handles)
    if strcmp(eventdata.Key,'escape')
        % override BUSY state, handy in case of bug
        BUSY(false);
        % cancel 2AFC process
        handles.zoom=[];
        handles.slideshow_cNrs=[];
        handles.slideshow_cNrs_done=[];
        handles.button_startstopslideshow.String='Start';
        % clean myPrint
        myPrint(handles);
    end
    if BUSY
        return;
    end
    
    if ~isempty(handles.slideshow_cNrs)
        % only working in slideshow modus
        if any(strcmp(eventdata.Key(end),{'1','1','2','3','4','0','u','s'})) % s for skip; % end is used to make, for exampl,e numpad1 as well as 1
            if strcmp(eventdata.Key(end),'1') && ~isundefined(handles.category_labels(1))
                handles.cellType(handles.cNrs==handles.slideshow_cNrs(end))=handles.category_labels(1);
            elseif strcmp(eventdata.Key(end),'2') && ~isundefined(handles.category_labels(2))
                handles.cellType(handles.cNrs==handles.slideshow_cNrs(end))=handles.category_labels(2);
            elseif strcmp(eventdata.Key(end),'3') && ~isundefined(handles.category_labels(3))
                handles.cellType(handles.cNrs==handles.slideshow_cNrs(end))=handles.category_labels(3);
            elseif strcmp(eventdata.Key(end),'4') && ~isundefined(handles.category_labels(4))
                handles.cellType(handles.cNrs==handles.slideshow_cNrs(end))=handles.category_labels(4);
            elseif strcmp(eventdata.Key,'u')
                handles.cellType(handles.cNrs==handles.slideshow_cNrs(end))='unlabeled';
            end
            % fill out the confidence level for this response, designed
            % to be a 1 to 5 stars rating
            if isempty(eventdata.Modifier)
                handles.confidenceStars(handles.cNrs==handles.slideshow_cNrs(end))=3;
            elseif numel(eventdata.Modifier)==1 && strcmp(eventdata.Modifier,'alt')
                handles.confidenceStars(handles.cNrs==handles.slideshow_cNrs(end))=5;
            end
            handles.slideshow_cNrs_done(end+1)=handles.slideshow_cNrs(end); % move to done list
            handles.slideshow_cNrs(end)=[]; % remove from todo list
            if isempty(handles.slideshow_cNrs) % completed all cells
                handles.zoom=[];
                handles.slideshow_cNrs=[];
                handles.button_startstopslideshow.String='Start';
            else
                guidata(hObject,handles);
                zoomInOnRoi(hObject,handles,handles.slideshow_cNrs(end)); % show the next cell
                return
            end
        elseif strcmp(eventdata.Key,{'b'}) && ~isempty(handles.slideshow_cNrs_done) % show previous cell, for example when wrong button pressed accidentally
            handles.slideshow_cNrs(end+1)=handles.slideshow_cNrs_done(end);
            handles.slideshow_cNrs_done(end)=[];
            guidata(hObject,handles);
            zoomInOnRoi(hObject,handles,handles.slideshow_cNrs(end));
            return
        elseif any(strcmp(eventdata.Key,{'equal','add'})) % zoom in
            if handles.zoom.wid>10
                handles.zoom.wid=handles.zoom.wid/1.05;
                handles.zoom.hei=handles.zoom.hei/1.05;
            end
        elseif any(strcmp(eventdata.Key,{'hyphen','subtract'})) % zoom out
            if handles.zoom.wid<size(handles.roimap,2)
                handles.zoom.wid=handles.zoom.wid*1.05;
                handles.zoom.hei=handles.zoom.hei*1.05;
            end
        end
    else
        % Disabled in slideshow modus:
        if numel(eventdata.Modifier)==0
        elseif numel(eventdata.Modifier)==1
            if strcmp(eventdata.Modifier,'control')
                if strcmp(eventdata.Key,'rightarrow')
                    handles.pmtShiftPx.x=handles.pmtShiftPx.x+1;
                elseif strcmp(eventdata.Key, 'leftarrow')
                    handles.pmtShiftPx.x=handles.pmtShiftPx.x-1;
                elseif strcmp(eventdata.Key, 'uparrow')
                    handles.pmtShiftPx.y=handles.pmtShiftPx.y-1;
                elseif strcmp(eventdata.Key, 'downarrow')
                    handles.pmtShiftPx.y=handles.pmtShiftPx.y+1;
                elseif any(strcmp(eventdata.Key,{'0','numpad0'}))
                    handles.pmtShiftPx=struct('x',0,'y',0);
                end
            end
        end
    end
    % available in both slide show as regular view
    if numel(eventdata.Modifier)==1 && strcmpi(eventdata.Modifier,'CTRL')
        if strcmpi(eventdata.Key, 'h')
            handles.checkHideOverlay.Value=~handles.checkHideOverlay.Value;
        end
    end
    %
    guidata(hObject, handles);
    displayMaps(hObject,handles);
    
    
    
    
    
   
    
    
    
    
function myPrint(handles,str)
    if nargin==1, str=[]; end
    persistent hStr
    if ~isempty(hStr)
        delete(hStr);
    end
    if ~isempty(handles) && ~isempty(str)
        hStr=text(handles.axes1,0.5,0.5,str,'Unit','normalized','FontSize',12,'HorizontalAlignment','center','Interpreter','none','Color','k','BackGroundColor',[1 1 1 .75],'Parent',handles.axes1);
    end
    drawnow
    
    
    % --- Executes on button press in buttonNormImage.
function buttonNormImage_Callback(hObject, eventdata, handles)
    if BUSY
        return;
    end
    if isempty(handles.pmt0map)
        return
    end
    handles.pmt0map_enhanced=conv2(handles.pmt0map,fspecial('disk', 12),'same');
    guidata(hObject, handles);
    displayMaps(hObject,handles);
    
    
    % --- Executes on slider movement.
function sliderPMT0_Callback(hObject, eventdata, handles)
    handles.sliderPMT0compress.TooltipString=num2str(-handles.sliderPMT0compress.Value);
    handles.sliderPMT0divnormPx.TooltipString=num2str(handles.sliderPMT0divnormPx.Value);
    handles.sliderPMT0divnormAmount.TooltipString=num2str(handles.sliderPMT0divnormAmount.Value);
    if handles.checkboxPmt0EnhanceEnable.Value
        handles.pmt0map_enhanced = enhance(handles,handles.pmt0map);
        guidata(hObject, handles);
        displayMaps(hObject,handles);
    end
    
    
    
function E=enhance(handles,O)
    if handles.checkboxPmt0EnhanceEnable.Value==0
        E=O;
    else
        % apply divisive normalization
        px=handles.sliderPMT0divnormPx.Value;
        factor=handles.sliderPMT0divnormAmount.Value;
        if factor>0
            E=conv2(O,fspecial('disk',px),'same');
            E=O./E;
            E=factor*E+(1-factor)*O;
        else
            E=O; % enhanced = original
        end
        % scale between 0 and 1
        E=E-min(E(:));
        E=E./max(E(:));
        % apply compression
        E=E.^-handles.sliderPMT0compress.Value;
    end
    
    
    % --- Executes on button press in checkboxPmt0EnhanceEnable.
function checkboxPmt0EnhanceEnable_Callback(hObject, eventdata, handles)
    displayMaps(hObject,handles);
    
    
function buttonDefaultPmt0Enhance_Callback(hObject, eventdata, handles)
    resetAll=strcmpi(eventdata,'all');
    if resetAll || contains(hObject.Tag,'Compression')
        handles.sliderPMT0compress.Value=-1;
        handles.sliderPMT0compress.TooltipString=num2str(-handles.sliderPMT0compress.Value);
    elseif resetAll || contains(hObject.Tag,'DivNormRadius')
        handles.sliderPMT0divnormPx.Value=12;
        handles.sliderPMT0divnormPx.TooltipString=num2str(handles.sliderPMT0divnormPx.Value);
    elseif resetAll || contains(hObject.Tag,'DivNormAmount')
        handles.sliderPMT0divnormAmount.Value=0;
        handles.sliderPMT0divnormAmount.TooltipString=num2str(handles.sliderPMT0divnormAmount.Value);
    end
    guidata(hObject,handles);
    displayMaps(hObject,handles);
    
    
    
    % --- Executes on mouse press over figure background.
function image_ButtonDownFcn(hObject, eventdata, handles)
    % handles=guidata(hObject);
    if isempty(handles.roimap)
        return;
    end
    a = round(get(handles.axes1,'CurrentPoint'));
    clickX=a(1);
    clickY=a(3);
    if clickX<1 || clickX>size(handles.roimap,2) || clickY<1 || clickY>size(handles.roimap,1)
        return;  % clicked outside window
    end
    clickedCellNr=handles.roimap(clickY,clickX);
    
    % Create a right-click menu for the image
    handles.image.UIContextMenu=uicontextmenu;
    if clickedCellNr>0
        for i=1:numel(handles.category_labels)
            if ~isundefined(handles.category_labels(i))
                uimenu(handles.image.UIContextMenu,'Label',sprintf('Label ROI %.3d %s',clickedCellNr,handles.category_labels(i)),'Callback',@(x,y)setCellType(x,y,hObject,handles));
            end
        end
        if ~isempty(handles.confidenceStars)
            % add the confidence star-rating options
            %   hLow=uimenu(handles.image.UIContextMenu,'Label','Confidence low','Callback',@(x,y)setCellTypeConfidenceStars(x,hObject,handles),'Separator','on');
            %   hMed=uimenu(handles.image.UIContextMenu,'Label','Confidence medium','Callback',@(x,y)setCellTypeConfidenceStars(x,hObject,handles));
            %   hHgh=uimenu(handles.image.UIContextMenu,'Label','Confidence high','Callback',@(x,y)setCellTypeConfidenceStars(x,hObject,handles));
            
            C= uimenu(handles.image.UIContextMenu,'Label','Confidence level','Separator','on');
            for i=1:5
                
                h(i)=uimenu(C,'Label',repmat('*',1,i),'Callback',@(x,y)setCellTypeConfidenceStars(x,hObject,handles));
                if handles.confidenceStars(handles.cNrs==clickedCellNr)==i
                    h(i).Checked='on';
                end
            end
            
        end
        
        % clear all labels options
        uimenu(handles.image.UIContextMenu,'Label','Clear all labels','Callback',@(x,y)setCellType(x,y,hObject,handles),'Separator','on');
        % highlighting cell type options
        ctypes=unique(handles.cellType(~isundefined(handles.cellType)));
        for i=1:numel(ctypes)
            u=uimenu(handles.image.UIContextMenu,'Label',['Highlight ' char(ctypes(i))],'Callback',@(x,y)cellTypesToHighlight(char(ctypes(i)),hObject,handles));
            if i==1
                u.Separator='on';
            end
            if any(handles.cellTypesToHighlight==ctypes(i))
                u.Checked='on';
            end
        end
    end
    
    
    
    
    
    
    
    
    
function setCellType(source,callbackdata,hObject,handles)
    if strcmpi(source.Label,'Clear all labels')
        % can be selected from anywhere within the image
        handles.cellType=repmat(categorical(cellstr('unlabeled')),size(handles.cNrs));
        handles.confidenceStars=nan(size(handles.cNrs));
    else
        % can only be selected on a specific cell
        N=regexp(handles.image.UIContextMenu.Children(end).Label,'\d+','match');
        if isempty(N)
            return;
        end
        clickedCellNr=str2double(N{1});
        if clickedCellNr==0
            return;
        end
        % set cells label to <undefined> if it was currently checked, or
        % set it to the new label if selection was unchecked
        if strcmpi(source.Checked,'on')
            handles.cellType(handles.cNrs==clickedCellNr)='unlabeled';
        else
            L=regexp(source.Label,' ','split'); % the last space separated part of the Label is the category label (that's why no space allowed in name)
            handles.cellType(handles.cNrs==clickedCellNr)=L{end};
        end
    end
    guidata(hObject,handles);
    displayMaps(hObject,handles);
    
function setCellTypeConfidenceStars(source,hObject,handles)
    % Get the cell number
    K={source.Parent.Parent.Children.Label};
    for i=1:numel(K)
        if contains(K{i},'Label ROI')
            N=regexp(handles.image.UIContextMenu.Children(end).Label,'\d+','match');
            clickedCellNr=str2double(N{1});
            if isnan(clickedCellNr) || clickedCellNr==0
                return;
            end
            break;
        end
    end
    handles.confidenceStars(handles.cNrs==clickedCellNr)=sum(source.Label=='*');
    guidata(hObject,handles);
    displayMaps(hObject,handles);
    
    
    
function cellTypesToHighlight(labelStr,hObject,handles)
    % figure out the index of the context meny that has been selected
    index=[];
    for i=1:numel(handles.image.UIContextMenu.Children)
        if contains(handles.image.UIContextMenu.Children(i).Label,['Highlight ' labelStr],'IgnoreCase',true)
            index=i;
            break
        end
    end
    if isempty(index)
        error('couldnt figure out index of selected item!');
    end
    if strcmp(handles.image.UIContextMenu.Children(index).Checked,'on')
        handles.cellTypesToHighlight(handles.cellTypesToHighlight==labelStr)=[];
    else
        handles.cellTypesToHighlight(end+1)=labelStr;
    end
    guidata(hObject,handles);
    displayMaps(hObject,handles);
    
    
    
    
    
    % --- Executes on button press in checkHideOverlay.
function checkHideOverlay_Callback(hObject, eventdata, handles)
    guidata(hObject,handles);
    displayMaps(hObject,handles);
    
    
function menu_file_Callback(hObject, eventdata, handles)
    
function menu_tools_Callback(hObject, eventdata, handles)
    
function menu_help_gettingstarted_Callback(hObject, eventdata, handles)
    info{1}='STEP 1';
    info{end+1}='To start work on a new file select';
    info{end+1}='   File>Load PMT0+1';
    info{end+1}='This will bring up a red and green microscope image. Then select';
    info{end+1}='   File>Load Segments';
    info{end+1}='to open the segments file created with sbxsegmentpoly to bring up the ROIs.';
    info{end+1}='';
    info{end+1}='Or, to continue with an existing celltype file: ';
    info{end+1}='   File>Load celltype file';
    info{end+1}='';
    info{end+1}='STEP 2';
    info{end+1}='Dim the Red channel completely';
    info{end+1}='Use the arrow keys to align the ROIs with the cells in the green channel';
    info{end+1}='';
    info{end+1}='STEP 3';
    info{end+1}='Maximize Red, dim green completely';
    info{end+1}='Optionally use the PMT0 enhancement controls to make the cells clearer (this doesn''t work so well)';
    info{end+1}='';
    info{end+1}='STEP 4';
    info{end+1}='Press the Start button (slideshow panel)';
    info{end+1}='Follow the onscreen instructions to classify all ROIs';
    info{end+1}='Tip: Use CTRL+H to toggle the ROI outline, they might bias judgments';
    info{end+1}='';
    info{end+1}='STEP 5';
    info{end+1}='Save your work using CTRL+S (You can do this at any time)';
    msgbox(info,['Getting started with ' mfilename ],'replace');
    
    
function menu_help_about_Callback(hObject, eventdata, handles)
    msgbox({mfilename,'Created by Jacob Duijnhouwer','September 2017'},'Info','modal');
    
function menu_tools_openinsbxsegmentpoly_Callback(hObject, eventdata, handles)
    if BUSY
        return;
    end
    try
        BUSY(true);
        if isempty(handles.segmentFilename)
            msg={'Load the PMT0+1 and SEGMENT files first'};
            uiwait(errordlg(msg,mfilename,'modal'));
            BUSY(false);
            return;
        end
        if isempty(handles.sbxsegmentpolyGui) || ~isvalid(handles.sbxsegmentpolyGui)
            myPrint(handles,{'Opening in sbxsegmentpoly:',handles.segmentFilename});
            handles.sbxsegmentpolyGui=sbxsegmentpoly('file',handles.segmentFilename);
            myPrint(handles);
        else
            figure(handles.sbxsegmentpolyGui);
        end
    catch me
        BUSY(false);
        rethrow(me);
    end
    BUSY(false);
    
    
    % --------------------------------------------------------------------
function menu_file_loadcelltype_Callback(hObject, eventdata, handles)
    
    
     uiwait(errordlg('not implemented yet, jacob 2017-10-18',mfilename,'modal'));
     return
     
     
    [filename, pathname] = uigetfile({'*_celltype.mat';'*.*'}, 'Pick a CELLTYPE file');
    if filename==0
        return; % user pressed cancel
    end
    celltype=load(fullfile(pathname,filename),'celltype');
    if ~isfield(celltype,'celltype')
        msg={'No CELLTYPE data found'};
        uiwait(errordlg(msg,mfilename,'modal'));
        return;
    end
    celltype=celltype.celltype;
    if exist([celltype.pmt01fname '.sbx'],'file')
        menu_file_loadpmt01_Callback(hObject, celltype.pmt01fname, handles);
        handles=guidata(hObject);
    else
        msg={'The PMT01 file referenced in the CELLTYPE file does not exist'};
        uiwait(errordlg(msg,mfilename,'modal'));
        return;
    end
    if exist(celltype.segmentFilename,'file')
        menu_file_loadsegments_Callback(hObject, celltype.segmentFilename, handles);
        handles=guidata(hObject);
    else
        msg={'The SEGMENT file referenced in the CELLTYPE file does not exist'};
        uiwait(errordlg(msg,mfilename,'modal'));
        return;
    end
    % Calculate the number of cells, to check consistency with this file
    segmentFileCellNrs=unique(handles.roimap);
    segmentFileCellNrs(segmentFileCellNrs==0)=[];
    if numel(segmentFileCellNrs)~=numel(celltype.cNrs) || ~all(segmentFileCellNrs==celltype.cNrs)
        msg{1}='The cell numbers in the CELLTYPE file and SEGMENTS file referenced in that GABAFLOW file dont''t match!';
        msg{end+1}='The the SEGMENTS file has probably been edited since the CELLTYPE file was created.';
        msg{end+1}='Can''t continue.';
        uiwait(errordlg(msg,mfilename,'modal'));
        handles=getFreshGlobals(hObject,handles);
        displayMaps(hObject,handles);
        return;
    end
    handles.cNrs=celltype.cNrs;
    % handles.segmentFilename=celltype.segmentFilename;
    % set the shift
    handles.pmtShiftPx=celltype.pmtShiftPx;
    % set the pmt0 image enhancement parameters
    fns=fieldnames(celltype.pmt0enhance);
    for i=1:numel(fns)
        handles.(fns{i}).Value=celltype.pmt0enhance.(fns{i});
        handles.(fns{i}).TooltipString=num2str(handles.(fns{i}).Value);
    end
    handles.editThresholdthold.String=num2str(celltype.thold);
    handles.cellType=celltype.cellType(:);
    handles.confidenceStars=celltype.confidenceStars(:);
    handles=guidata(hObject);
    displayMaps(hObject,handles);
    
    
    % --------------------------------------------------------------------
function menu_file_loadpmt01_Callback(hObject, eventdata, handles)
    global info %#ok<NUSED> % very unfortunate that sbxread has been designed around global variables ...
    try
        BUSY(true);
        if ~ischar(eventdata) || ~exist([eventdata '.sbx'],'file')
            [filename, pathname] = uigetfile({'*.sbx';'*.*'}, 'Pick an SBX file that contains PMT0 and PMT1 data');
            if filename==0
                BUSY(false);
                return; % user pressed cancel
            end
            handles=getFreshGlobals(hObject,handles); % reset everything
            [~,filename,~]=fileparts(filename); % removes extension from filename
            handles.pmt01fname=fullfile(pathname,filename); % makes filename absolute
        else
            handles=getFreshGlobals(hObject,handles); % reset everything
            handles.pmt01fname=eventdata;
        end
        try
            [~,fn]=fileparts(handles.pmt01fname);
            fn_info=dir([handles.pmt01fname '.sbx']);
            myPrint(handles,sprintf('Loading: ''%s.sbx'' (%d MB)',fn,round(fn_info.bytes/2^20)));
            C = sbxread_allframes(handles.pmt01fname);
            if size(C,1)~=2
                msg={'The selected file contains only 1 PMT channel'};
                msg{end+1}='Can''t continue';
                uiwait(errordlg(msg,mfilename,'modal'));
                handles=getFreshGlobals(hObject,handles);
                guidata(hObject, handles);
                displayMaps(hObject,handles);
                return;
            end
            C = double(C)./double(intmax('uint16'));
            handles.pmt1map = squeeze(mean(C(1,:,:,:),4)); %squeeze(max(C(1,:,:,:),[],4));
            handles.pmt0map = squeeze(mean(C(2,:,:,:),4)); %squeeze(max(C(2,:,:,:),[],4));
            handles.pmt0map_enhanced = enhance(handles,handles.pmt0map);
            set(handles.figure1,'Name',[mfilename ' - ' fn]); % Set the title of the main window
        catch me
            BUSY(false);
            rethrow(me);
        end
        if ~isempty(handles.roimap) && ~all(size(handles.roimap)==size(handles.pmt0map))
            msg={'Segment mask and PMT0+1 masks have different dimensions! Width and height in pixels don''t match'};
            uiwait(errordlg(msg,mfilename,'modal'));
            handles=getFreshGlobals(hObject,handles);
            guidata(hObject, handles);
            displayMaps(hObject,handles);
            return;
        end
        guidata(hObject, handles);
        displayMaps(hObject,handles);
        myPrint(handles);
    catch me
        BUSY(false);
        rethrow(me);
    end
    BUSY(false);
    
    
    % --------------------------------------------------------------------
function menu_file_loadsegments_Callback(hObject, eventdata, handles)
    try
        BUSY(true);
        if isempty(handles.pmt0map)
            msg={'Load a PMT0+1 file first'};
            uiwait(errordlg(msg,mfilename,'modal'));
            BUSY(false);
            return;
        end
        try
            % assuming the MOUSE_DATE_SESSIONNUMBER nomenclature for filenames,
            % figure out the name corresponding to PMT0+1 file.
            [startfolder,mouse_date_ses,~]=fileparts(handles.pmt01fname);
            mouse_date_=mouse_date_ses(1:find(mouse_date_ses=='_',1,'last'));
        catch
            startfolder=pwd;
            mouse_date_='';
        end
        if ~ischar(eventdata) || ~exist(eventdata,'file')
            [filename, pathname] = uigetfile({[mouse_date_ '*.segment'];'*.segment';'*.*'}, 'Pick a Segment file',startfolder);
            if filename==0
                BUSY(false);
                return; % user pressed cancel
            end
            handles.segmentFilename=fullfile(pathname,filename); % makes filename absolute
        else
            handles.segmentFilename=eventdata;
            [~,filename,ext]=fileparts(eventdata);
            filename=[filename '.' ext];
        end
        fn_info=dir(handles.segmentFilename);
        myPrint(handles,sprintf('Loading: ''%s'' (%d MB)',filename,round(fn_info.bytes/2^20)));
        myPrint(handles,['Loading ''' filename ''' ...']);
        K=load(handles.segmentFilename,'mask','-mat');
        if ~isfield(K,'mask')
            msg={'No mask data found!'};
            uiwait(errordlg(msg,mfilename,'modal'));
            BUSY(false);
            myPrint(handles);
            return;
        elseif ~isempty(handles.pmt0map) && ~all(size(K.mask)==size(handles.pmt0map))
            msg={'Segment mask and PMT0+1 masks have different dimensions! Width and height in pixels don''t match'};
            uiwait(errordlg(msg,mfilename,'modal'));
            BUSY(false);
            myPrint(handles);
            return;
        end
        handles.roimap=K.mask;
        % create a list of cell numbers
        handles.cNrs=unique(handles.roimap); % not necessarily consecutive -> list is needed for indexing
        handles.cNrs(handles.cNrs==0)=[]; % 0 is the background
        % create a corresponding categorical list of cell types
        handles.cellType=repmat(categorical(cellstr('unlabeled')),size(handles.cNrs));
        handles.confidenceStars=nan(size(handles.cNrs));
        % get the outlines of the ROIs
        handles.outlines=handles.roimap*0;
        for c=handles.cNrs(:)'
            bnds = bwboundaries(handles.roimap==c);
            bnds = bnds{1};
            for v=1:size(bnds,1)
                handles.outlines(bnds(v,1),bnds(v,2))=c;
            end
        end
        % get the centroids of the ROIs
        handles.centroids=zeros(numel(handles.cNrs),2);
        handles.roiboxes=zeros(numel(handles.cNrs),4);
        [XX,YY]=meshgrid(1:size(handles.outlines,2),1:size(handles.outlines,1));
        for i=1:numel(handles.cNrs)
            handles.centroids(i,1)=mean(XX(handles.roimap==handles.cNrs(i)));
            handles.centroids(i,2)=mean(YY(handles.roimap==handles.cNrs(i)));
            handles.roiboxes(i,1)=min(XX(handles.roimap==handles.cNrs(i)));
            handles.roiboxes(i,2)=min(YY(handles.roimap==handles.cNrs(i)));
            handles.roiboxes(i,3)=max(XX(handles.roimap==handles.cNrs(i)));
            handles.roiboxes(i,4)=max(YY(handles.roimap==handles.cNrs(i)));
        end
        % make sure hiding overlay isn't off
        handles.checkHideOverlay.Value=false;
        %
        guidata(hObject,handles);
        displayMaps(hObject,handles);
        myPrint(handles);
    catch me
        BUSY(false);
        rethrow(me);
    end
    BUSY(false);
    
    
    % --------------------------------------------------------------------
function menu_file_savecelltype_Callback(hObject, eventdata, handles)
    if BUSY
        return;
    end
    if checkDataLoaded(hObject, handles)>0
        return;
    end
    try
        [pth,fn,~]=fileparts(handles.segmentFilename);
        ffname=fullfile(pth,[fn '_celltype.mat']);
        [fn, pth] = uiputfile('*.*', 'Save CELLTYPE data as ...',ffname);
        if isequal(fn,0)
            return; % user pressed cancel
        end
        ffname=fullfile(pth,fn);
        
        BUSY(true);
        %
        celltype.pmt01fname=handles.pmt01fname;
        celltype.segmentFilename=handles.segmentFilename;
        celltype.pmt0map=handles.pmt0map;
        celltype.pmt1map=handles.pmt1map;
        celltype.roimap=handles.roimap; % same as the mask from the segmentfile, use it to check if the segmentfile and this thing are still compatible
        celltype.pmt0enhancements=struct('checkboxPmt0EnhanceEnable',handles.checkboxPmt0EnhanceEnable.Value,'sliderPMT0compress',handles.sliderPMT0compress.Value,'sliderPMT0divnormPx',handles.sliderPMT0divnormPx.Value,'sliderPMT0divnormAmount',handles.sliderPMT0divnormAmount.Value);
        celltype.pmt0map_enhanced=handles.pmt0map_enhanced;
        celltype.pmtShiftPx=handles.pmtShiftPx;
        celltype.cNrs=handles.cNrs(:);
        celltype.cellType=handles.cellType(:);
        celltype.confidenceStars=handles.confidenceStars(:);
        myPrint(handles,{'Saving',ffname})
        save(ffname,'celltype','-mat');
        pause(1.5);
        myPrint(handles)
        BUSY(false);
    catch me
        BUSY(false);
        rethrow(me);
    end

    
    
    
    
    % --- Executes on button press in button_startstopslideshow.
function button_startstopslideshow_Callback(hObject, eventdata, handles)
    if checkDataLoaded(hObject, handles)>0
        return
    end
    if strcmpi(handles.button_startstopslideshow.String,'Start')
        if ~handles.check_onlyhighlightedrois.Value
            handles.slideshow_cNrs=handles.cNrs;
        else
            include=handles.cellType==handles.cellTypesToHighlight(1);
            for i=2:numel(handles.cellTypesToHighlight)
                include=include | handles.cellType==handles.cellTypesToHighlight(i);
            end
            handles.slideshow_cNrs=handles.cNrs(include);
        end
        if ~isempty(handles.slideshow_cNrs)
            if ~handles.sliderPmtOneOpacity.Value==0
                msg={'Green channel will be set to invisible during Slideshow because that''s the best way to see if there''s any red in the cell or not.'};
                uiwait(warndlg(msg,mfilename,'modal'));
                handles.sliderPmtOneOpacity.Value=0;
            end
            handles.button_startstopslideshow.String='Stop';
            handles.slideshow_cNrs=handles.slideshow_cNrs(randperm(numel(handles.slideshow_cNrs))); % do in random order
            zoomInOnRoi(hObject,handles,handles.slideshow_cNrs(end));
            handles=guidata(hObject);
        else
            handles.slideshow_cNrs=[];
            handles.zoom=[];
            handles.button_startstopslideshow.String='Start';
            if ~handles.check_onlyhighlightedrois.Value
                msg={'No highlighted ROIs'};
            else
                msg={'No ROIs'};
            end
            uiwait(warndlg(msg,mfilename,'modal'));
        end
        handles.slideshow_cNrs_done=[];
    else
        handles.button_startstopslideshow.String='Start';
        handles.slideshow_cNrs=[];
        handles.zoom=[];
    end
    guidata(hObject,handles);
    displayMaps(hObject,handles);
    
    
function zoomInOnRoi(hObject,handles,c)
    if ~any(handles.cNrs==c)
        warning('illegal cellnumer');
        handles.zoom=[];
    else
        handles.zoom.cNr=c;
        handles.zoom.center=handles.centroids(handles.cNrs==c,:);
        roibox_wid=handles.roiboxes(handles.cNrs==c,3)-handles.roiboxes(handles.cNrs==c,1);
        roibox_hei=handles.roiboxes(handles.cNrs==c,4)-handles.roiboxes(handles.cNrs==c,2);
        handles.zoom.wid=roibox_wid*8;
        handles.zoom.hei=roibox_hei*8;
    end
    guidata(hObject,handles);
    displayMaps(hObject,handles);
    
    
    
    % --- Executes on button press in check_onlyhighlightedrois.
function check_onlyhighlightedrois_Callback(hObject, eventdata, handles)
    if ~isempty(handles.slideshow_cNrs)
        msg={'Can not toggle "Highlighted only" after Slideshow has started'};
        uiwait(errordlg(msg,mfilename,'modal'));
        handles.check_onlyhighlightedrois.Value=~handles.check_onlyhighlightedrois.Value; % toggle it back
        return;
    end
    
    
function S=zeroshift(M,dx,dy)
    dx=round(dx);
    dy=round(dy);
    if dx==0 && dy==0
        S=M;
        return;
    end
    S=zeros(size(M));
    if dy==0
        if dx>0
            S(:,1+dx:end)=M(:,1:end-dx);
        elseif dx<0
            S(:,1:end+dx)=M(:,1-dx:end);
        end
    end
    
    
function M=padshift(M,dx,dy,padval)
    dx=round(dx);
    dy=round(dy);
    if dx==0 && dy==0
        return;
    end
    if nargin==3
        padval=0;
    end
    hei=size(M,1);
    wid=size(M,2);
    M=circshift(M,[dy dx]);
    if dy>0
        M(1:dy,:)=padval;
    else
        M(hei+dy:hei,:)=padval;
    end
    if dx>0
        M(:,1:dx)=padval;
    else
        M(:,wid+dx:wid)=padval;
    end
    
    
    
    % --- Executes on button press in buttonUpdateLabels.
function buttonUpdateLabels_Callback(hObject, eventdata, handles)
    %  keyboard
    %     handles.panel_categories.Visible='off';% ~handles.panel_categories.Visible;
    
    %    return
    for i=1:4
        old_label=handles.category_labels(i);
        fieldname=sprintf('editLabel%d',i);
        new_label=strtrim(handles.(fieldname).String);
        if isempty(new_label)
            new_label='<undefined>';
        end
        new_label(new_label==' ')='_';
        handles.(fieldname).String=new_label;
        if new_label~=old_label
            if ~isempty(handles.cellType) && any(handles.cellType==old_label)
                msg{1}=sprintf('You are changing the label %s to %s.',old_label, new_label);
                msg{2}=sprintf('%d cells are currently labeled as %s.',sum(handles.cellType==old_label),old_label);
                msg{3}=sprintf('Do you want to update the labels of those cells?');
                butName = questdlg(msg,mfilename,'Cancel',sprintf('Change to %s',new_label),sprintf('Keep as %s',old_label),sprintf('Keep as %s',old_label));
                if strcmpi(butName,'Cancel')
                    handles.(fieldname).String=char(old_label);
                elseif contains(butName,new_label)
                    handles.cellType(handles.cellType==old_label)=new_label;
                end
            end
            handles.category_labels(i)=new_label;
        end
    end
    guidata(hObject,handles);
    displayMaps(hObject,handles);
    
    
    
    
        % --- Executes when figure1 is resized.
function figure1_SizeChangedFcn(hObject, eventdata, handles)
    % rescale the image (axes1) so it has maximum surface
    handles.figure1.Units='pixels';
    handles.axes1.Units='pixels';
    handles.panel_opacities.Units='pixels';
    handles.panel_imageshift.Units='pixels';
    handles.panel_pmt0enhance.Units='pixels';
    handles.panel_slideshow.Units='pixels';
    handles.panel_categories.Units='pixels';
    guiWidPx=handles.figure1.Position(3);
    guiHeiPx=handles.figure1.Position(4);
    margPx=2; % for aesthetics
    % set the left position of all panels
    handles.panel_opacities.Position(1)=margPx;
    handles.panel_imageshift.Position(1)=margPx;
    handles.panel_pmt0enhance.Position(1)=margPx;
    handles.panel_slideshow.Position(1)=margPx;
    handles.panel_categories.Position(1)=margPx;
    % set their widths, panel_opacities is the ground truth one
    handles.panel_imageshift.Position(3)=handles.panel_opacities.Position(3);
    handles.panel_pmt0enhance.Position(3)=handles.panel_opacities.Position(3);
    handles.panel_slideshow.Position(3)=handles.panel_opacities.Position(3);
    handles.panel_categories.Position(3)=handles.panel_opacities.Position(3);
    % Set the axes1 size and position
    ctrlPx=sum(handles.panel_opacities.Position([1 3])); % lefthandControlsWidthPx
    handles.axes1.Position=[ctrlPx+margPx margPx guiWidPx-ctrlPx-2*margPx guiHeiPx-2*margPx];
    % set the top positions
    handles.panel_opacities.Position(2)=guiHeiPx-handles.panel_opacities.Position(4);
    handles.panel_imageshift.Position(2)=handles.panel_opacities.Position(2)-handles.panel_imageshift.Position(4)-margPx;
    handles.panel_pmt0enhance.Position(2)=handles.panel_imageshift.Position(2)-handles.panel_pmt0enhance.Position(4)-margPx;
    handles.panel_slideshow.Position(2)=handles.panel_pmt0enhance.Position(2)-handles.panel_slideshow.Position(4)-margPx;
    handles.panel_categories.Position(2)=handles.panel_slideshow.Position(2)-handles.panel_categories.Position(4)-margPx;

    
