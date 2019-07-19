function sig = sbxpullsignals(fname)
    
    
    if endsWith(fname,'.segment')
        fname=fname(1:end-numel('.segment'));
    end
    
    load([fname '.segment'],'-mat','mask'); % load segmentation variable 'mask'
    
    z = sbxread(fname,1,1);
    
    global info;
    
    ncell = max(mask(:));
    
    roi_npix=nan(1,ncell);
    for(i=1:ncell)
        roi_idx{i} = find(mask==i);
        roi_npix(1,i) = numel(roi_idx{i});
    end
    
    sig = zeros(info.max_idx, ncell);
    
    h = waitbar(0,sprintf('Pulling %d %d-sample signals from %s...',ncell,info.max_idx,strrep(fname,'_','-')));
    
    for i=0:info.max_idx-1
        if mod(i,round(info.max_idx/100))==0 || i==info.max_idx-1
            waitbar(i/(info.max_idx-1),h);          % update waitbar...
        end
        z = sbxread(fname,i,1);
        if size(z,1)==2 % file has been recorded with PMT0 and PMT1, probably by accident
            z=z(2,:,:); % discard PMT0 data
        end
        z = squeeze(z(1,:,:));
        z = circshift(z,info.aligned.T(i+1,:)); % align the image
        for j=1:ncell                          % for each cell
            sig(i+1,j) = sum(z(roi_idx{j}));       % pull the signal out..., divide later by the number of elements. Mean is a slower than sum and this line gets called millions of times; jacob
        end
    end
    % divide by the number of pixels in each roi,
    sig=sig./roi_npix(:)'; % each column in sig divided by corresponding element in vector npix; jacob
    
    disp('SUM VS MEAN NOT BEEN TESTED YET; TODO!')
    
    save([fname '.signals'],'sig','mask'); % 20171010, store the mask too so that compatibilty with segment file can be checked
    
    delete(h);
