function [rgb,info]=fusiReadBModeUnderlay(file,shape,selection)
% Read reconstructed B-mode anatomy only; never change signal data.
% Grayscale temporal recordings are averaged for a static display. Three
% spatial planes remain three planes, rather than being mistaken for RGB.
% Rendered montage snapshots require explicit panel-to-slice mapping. They
% must never be stretched beneath, or repeated over, the whole volume.
if nargin<3,selection=[];end
shape=double(shape(:)');shape(end+1:3)=1;
assert(numel(shape)==3&&all(isfinite(shape)&shape>0&shape==round(shape)),'deConfUSIon:BModeGrid','Invalid recording grid.');
assert(isfile(file),'deConfUSIon:BModeFile','B-mode file not found: %s',file);
[~,~,ext]=fileparts(file);project=false;rawMetadata=struct();
switch lower(ext)
    case '.mat'
        vars=whos('-file',file);vars=vars(:)';
        header=find(strcmp({vars.name},'metadata')&strcmp({vars.class},'struct'),1);
        if ~isempty(header)&&vars(header).bytes<=4*1024^2
            S=load(file,'metadata');rawMetadata=S.metadata;
        end
        numeric=ismember({vars.class},{'single','double','uint8','uint16','uint32','int8','int16','int32','logical'});
        candidates=find(numeric & arrayfun(@(v)numel(v.size)>=2&&all(v.size(1:2)>1),vars));
        pref={'bmode','b_mode','bmodeimage','bmodergb','bmode_rgb','brainimage','anatomical_reference_raw','underlay','img','image','i','data'};
        chosen=[];
        for k=1:numel(pref)
            chosen=candidates(strcmpi({vars(candidates).name},pref{k}));
            if ~isempty(chosen),chosen=chosen(1);break;end
        end
        if isempty(chosen)&&numel(candidates)==1,chosen=candidates;end
        assert(~isempty(chosen),'deConfUSIon:BModeVariable', ...
            'Choose a reconstructed B-mode MAT with an I, bmode or image array.');
        v=vars(chosen);field=v.name;isRGB=contains(lower(field),'rgb');
        assert(~v.complex,'deConfUSIon:BModeComplex','Choose reconstructed B-mode anatomy; complex IQ data must be reconstructed first.');
        assert(~v.sparse,'deConfUSIon:BModeVariable','Sparse image arrays are not supported.');
        % Large v7.3 movies can be projected without loading the movie at once.
        sz=v.size;tdim=numel(sz);
        if ~isRGB
            project=(tdim==3&&shape(3)==1)||(tdim==4&&sz(3)==shape(3));
        end
        outShape=sz;if project,outShape(end)=1;end
        checkGrid(outShape,isRGB);
        assert(prod(outShape)*12<=512*1024^2,'deConfUSIon:BModeMemory','This B-mode volume is too large for a display underlay.');
        if project && H5F.is_hdf5(file)
            U=zeros(outShape,'single');counts=zeros(outShape,'single');
            m=matfile(file);subs=repmat({':'},1,tdim);
            chunk=max(1,floor(8*1024^2/max(1,v.bytes/sz(end))));
            for first=1:chunk:sz(end)
                subs{end}=first:min(sz(end),first+chunk-1);
                block=single(subsref(m,substruct('.',field,'()',subs)));
                valid=isfinite(block);block(~valid)=0;
                U=U+sum(block,tdim);counts=counts+sum(single(valid),tdim);
            end
            U=U./counts;U(counts==0)=NaN;
        else
            assert(v.bytes<=512*1024^2,'deConfUSIon:BModeMemory', ...
                'Choose a static B-mode image or a v7.3 MAT for a large B-mode movie.');
            S=load(file,field);U=S.(field);
            if project,U=single(U);U(~isfinite(U))=NaN;U=mean(U,tdim,'omitnan');end
        end
    case {'.png','.jpg','.jpeg','.bmp','.tif','.tiff'}
        field='';
        [U,map]=imread(file);
        if ~isempty(map),U=ind2rgb(U,map);end
        isRGB=ndims(U)==3&&size(U,3)==3;
        if any(strcmpi(ext,{'.tif','.tiff'}))
            pages=imfinfo(file);
            if numel(pages)>1
                assert(~isRGB&&numel(pages)==shape(3),'deConfUSIon:BModeGrid', ...
                    'A TIFF stack must contain one grayscale image per recording slice.');
                first=U;U=zeros(size(first,1),size(first,2),numel(pages),'like',first);U(:,:,1)=first;
                for k=2:numel(pages),U(:,:,k)=imread(file,k);end
            end
        end
    otherwise
        error('deConfUSIon:BModeFile','Supported B-mode files: MAT, PNG, TIFF, JPEG and BMP.');
end
assert(isreal(U)&&~isempty(U),'deConfUSIon:BModeVariable','Choose a real reconstructed B-mode image.');
sourceShape=checkGrid(size(U),isRGB);
assert(numel(U)*12<=512*1024^2,'deConfUSIon:BModeMemory','This B-mode volume is too large for a display underlay.');
valid=isfinite(U);assert(any(valid(:)),'deConfUSIon:BModeEmpty','The B-mode image has no finite pixels.');
if isRGB
    if isinteger(U),rgb=single(U)/single(intmax(class(U)));
    else,rgb=single(U);if max(rgb(valid))>1,limits=fusiFiniteDisplayLimits(rgb);rgb=(rgb-limits(1))/diff(limits);end
    end
else
    limits=fusiFiniteDisplayLimits(U);U=single(U);U=(U-limits(1))/diff(limits);
    rgb=repmat(reshape(U,sourceShape(1),sourceShape(2),1,sourceShape(3)),[1 1 3 1]);
    valid=repmat(reshape(valid,sourceShape(1),sourceShape(2),1,sourceShape(3)),[1 1 3 1]);
end
rgb=min(1,max(0,rgb));rgb(~valid)=0;
rendered=isfield(rawMetadata,'vendor_rendered_montage')&&isequal(double(rawMetadata.vendor_rendered_montage),1);
needsMapping=rendered||sourceShape(3)~=shape(3);
info=struct('file',char(file),'field',field,'spatialSize',sourceShape,'sourceSpatialSize',sourceShape, ...
    'recordingSize',shape,'metadata',rawMetadata,'isRGB',isRGB,'isSnapshot',sourceShape(3)==1, ...
    'isTemporalMean',project,'needsSliceMapping',needsMapping,'validSlices',false(1,shape(3)), ...
    'description','Assign B-mode panels to Doppler slices','mapping',struct());
if isa(selection,'function_handle')
    if needsMapping
        selection=selection(rgb,info);
        if isempty(selection),return;end
    else
        selection=[];
    end
end
if isempty(selection)&&~needsMapping
    selection=struct('kind','planes','sliceIndices',1:shape(3));
end
if ~isempty(selection)
    [rgb,mapping]=fusiMapBModeSlices(rgb,shape,selection);
    info.mapping=mapping;info.validSlices=mapping.validSlices;info.needsSliceMapping=false;
    info.spatialSize=shape;info.isSnapshot=shape(3)==1;
    info.description=sprintf('B-mode mapped to %d/%d Doppler slices',nnz(info.validSlices),shape(3));
end
end

function actual=checkGrid(sz,isRGB)
if isRGB
    sz(end+1:4)=1;
    assert(numel(sz)==4&&sz(3)==3,'deConfUSIon:BModeGrid','Expected RGB B-mode anatomy.');
    actual=sz([1 2 4]);
else
    % Trailing singleton dimensions are not spatial planes or time frames.
    while numel(sz)>3&&sz(end)==1,sz(end)=[];end
    sz(end+1:3)=1;
    assert(numel(sz)==3,'deConfUSIon:BModeGrid','Expected a B-mode image or spatial volume.');
    actual=sz;
end
assert(all(actual>0),'deConfUSIon:BModeGrid','B-mode image planes must be nonempty.');
end
