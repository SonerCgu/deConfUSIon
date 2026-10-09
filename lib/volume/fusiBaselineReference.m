function varargout=fusiBaselineReference(action,varargin)
% Shared, absolute Doppler baseline. Never derive a reference from local PSC.
switch action
    case 'isExternal'
        b=varargin{1};varargout{1}=isstruct(b)&&isfield(b,'reference')&&~isempty(b.reference);
    case 'build'
        I=varargin{1};TR=varargin{2};w=double(varargin{3});
        assert(ndims(I)==3||ndims(I)==4,'deConfUSIon:BaselineSeries','Select a Doppler time series.');
        T=size(I,ndims(I));
        assert(isscalar(TR)&&isfinite(TR)&&TR>0,'deConfUSIon:BaselineTR','Reference TR must be positive.');
        assert(numel(w)==2&&all(isfinite(w))&&w(1)>=0&&w(2)>w(1)&&w(2)<=(T-1)*TR, ...
            'deConfUSIon:BaselineWindow','Reference window must lie inside scan 1 (0 to %.6g s).',(T-1)*TR);
        frames=round(w/TR)+1;q=repmat({':'},1,ndims(I));q{end}=frames(1):frames(2);
        B=single(deConfUSIon_signal('mean',I(q{:}),ndims(I)));
        B(~isfinite(B)|B<=0)=NaN;
        assert(any(isfinite(B(:))),'deConfUSIon:BaselinePower','Reference has no positive, finite Doppler baseline. Select linear power data, not PSC or zero-centred data.');
        ref=struct('kind','FUSI_SHARED_BASELINE','version',1,'mean',B,'TR',TR, ...
            'requestedWindowSec',w(:).','windowSec',(frames-1)*TR,'frames',frames, ...
            'nFrames',T,'spatialSize',size(I,1:ndims(I)-1),'created',datestr(now,30), ...
            'sourceFile','','rawFile','','datasetLabel','Reference scan');
        if numel(I)*4<=32*1024^2
            ref.tracePower=single(I);ref.traceFrames=1:T;
        elseif prod(ref.spatialSize)*diff([frames(1)-1 frames(2)])*4<=32*1024^2
            ref.tracePower=single(I(q{:}));ref.traceFrames=frames(1):frames(2);
        end
        if numel(varargin)>3
            p=varargin{4};for f=fieldnames(p)',ref.(f{1})=p.(f{1});end
        end
        varargout{1}=ref;
    case 'validate'
        ref=varargin{1};shape=double(varargin{2});
        assert(isstruct(ref)&&all(isfield(ref,{'kind','mean','spatialSize','TR','frames','windowSec'}))&&strcmp(ref.kind,'FUSI_SHARED_BASELINE') ...
            &&isnumeric(ref.mean)&&isreal(ref.mean), ...
            'deConfUSIon:BaselineReference','Invalid shared baseline file.');
        assert(isequal(double(ref.spatialSize(:).'),shape(:).')&&numel(ref.mean)==prod(shape), ...
            'deConfUSIon:BaselineGrid','Reference grid %s differs from current grid %s. Use scans aligned to the same spatial grid.',mat2str(ref.spatialSize),mat2str(shape));
        B=single(reshape(ref.mean,shape));B(~isfinite(B)|B<=0)=NaN;
        assert(any(isfinite(B(:))),'deConfUSIon:BaselinePower','Reference has no usable baseline voxels.');
        varargout{1}=B;
    case 'label'
        b=varargin{1};s='Current scan';
        if fusiBaselineReference('isExternal',b)
            r=b.reference;name='reference scan';
            if isfield(r,'datasetLabel'),name=r.datasetLabel;end
            if isfield(r,'rawFile')&&~isempty(r.rawFile),[~,scan]=fileparts(r.rawFile);name=[scan ': ' name];end
            s=sprintf('%s | %.6g-%.6g s (source scan)',name,r.windowSec);
        end
        varargout{1}=s;
    otherwise,error('deConfUSIon:BaselineAction','Unknown baseline action: %s',action);
end
end
