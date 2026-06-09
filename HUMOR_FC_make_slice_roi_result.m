function res = HUMOR_FC_make_slice_roi_result(s,subIdx,resIn,zSel)
% True slice-specific ROI FC result.
% Recomputes ROI time courses from selected Z slice and preserves L/R labels.

res = resIn;
try
    if nargin < 4 || isempty(zSel), zSel = s.slice; end
    if isempty(resIn) || ~isstruct(resIn), return; end
    if ~isfield(s,'Z') || s.Z <= 1, return; end
    if isfield(s,'sliceRegionOnly') && ~s.sliceRegionOnly, return; end
    if ~isfield(s,'subjects') || subIdx < 1 || subIdx > numel(s.subjects), return; end

    subj = s.subjects(subIdx);
    if ~isfield(subj,'I4') || isempty(subj.I4), return; end
    if ~isfield(subj,'roiAtlas') || isempty(subj.roiAtlas), return; end

    I4 = subj.I4;
    atlas = subj.roiAtlas;
    [Y,X,Z,T] = size(I4); %#ok<ASGLU>
    z = max(1,min(Z,round(zSel)));

    if ndims(atlas) < 3
        atlasS = round(double(atlas));
    else
        zA = max(1,min(size(atlas,3),z));
        atlasS = round(double(atlas(:,:,zA)));
    end
    if size(atlasS,1) ~= Y || size(atlasS,2) ~= X
        atlasS = localResizeNearest(atlasS,Y,X);
    end

    if isfield(subj,'mask') && ~isempty(subj.mask)
        M0 = subj.mask;
        if ndims(M0) >= 3
            zM = max(1,min(size(M0,3),z));
            maskS = logical(M0(:,:,zM));
        else
            maskS = logical(M0);
        end
        if size(maskS,1) ~= Y || size(maskS,2) ~= X
            maskS = logical(localResizeNearest(double(maskS),Y,X));
        end
    else
        maskS = true(Y,X);
    end

    if isfield(resIn,'timeIdx') && ~isempty(resIn.timeIdx)
        idxT = round(double(resIn.timeIdx(:)));
        idxT = idxT(isfinite(idxT) & idxT >= 1 & idxT <= size(I4,4));
        if isempty(idxT), idxT = 1:size(I4,4); end
    else
        idxT = 1:size(I4,4);
    end

    Izt = I4(:,:,z,idxT);
    D = reshape(double(Izt),Y*X,numel(idxT));
    atlasV = atlasS(:);
    maskV  = maskS(:);

    minVox = 1;
    try
        if isfield(s,'opts') && isfield(s.opts,'roiMinVox')
            minVox = max(1,round(double(s.opts.roiMinVox)));
        end
    catch
        minVox = 1;
    end

    % Use original ROI labels/names whenever available so L/R modes work.
    baseLabels = [];
    baseNames  = {};
    try, baseLabels = double(resIn.labels(:)); catch, end
    try, baseNames = cellstr(resIn.names(:)); catch, end

    labsSlice = unique(atlasV(maskV & atlasV ~= 0));
    labsSlice = labsSlice(:);
    labsSlice = labsSlice(isfinite(labsSlice) & labsSlice ~= 0);
    if isempty(labsSlice), return; end

    signedAtlas = any(labsSlice < 0);
    signedBase  = any(baseLabels < 0);

    outLabels = [];
    if ~isempty(baseLabels)
        absSlice = unique(abs(round(double(labsSlice(:)))));
        for kk = 1:numel(absSlice)
            aLab = absSlice(kk);
            if signedAtlas
                % If atlas itself is signed, keep exact side-specific labels.
                exactLabs = unique(round(double(labsSlice(abs(round(double(labsSlice))) == aLab))));
                for ee = 1:numel(exactLabs)
                    ix = find(round(baseLabels) == exactLabs(ee),1,'first');
                    if ~isempty(ix), outLabels(end+1,1) = baseLabels(ix); end %#ok<AGROW>
                end
            else
                % Positive-only slice atlas: preserve all original L/R variants for this region.
                ixAll = find(abs(round(baseLabels)) == aLab);
                if ~isempty(ixAll)
                    outLabels = [outLabels; baseLabels(ixAll(:))]; %#ok<AGROW>
                else
                    outLabels(end+1,1) = aLab; %#ok<AGROW>
                end
            end
        end
        outLabels = unique(outLabels,'stable');
    else
        outLabels = labsSlice;
    end

    keepLabels = [];
    names = {};
    counts = [];
    meanTS = [];

    for k = 1:numel(outLabels)
        labOut = round(double(outLabels(k)));
        if signedAtlas
            pix = find(maskV & atlasV == labOut);
            if isempty(pix)
                pix = find(maskV & abs(atlasV) == abs(labOut));
            end
        else
            pix = find(maskV & abs(atlasV) == abs(labOut));
        end
        if numel(pix) < minVox, continue; end

        nm = localROINameFromBase(labOut,baseLabels,baseNames,s);
        if localIsBackground(labOut,nm), continue; end

        ts = mean(D(pix,:),1)';
        keepLabels(end+1,1) = labOut; %#ok<AGROW>
        counts(end+1,1) = numel(pix); %#ok<AGROW>
        names{end+1,1} = nm; %#ok<AGROW>
        meanTS(:,end+1) = ts; %#ok<AGROW>
    end

    if numel(keepLabels) < 2, return; end
    R = localCorr(meanTS);

    res = resIn;
    res.labels = keepLabels;
    res.names = names;
    res.counts = counts;
    res.meanTS = meanTS;
    res.M = R;
    res.R = R;
    res.TR = subj.TR;
    res.timeIdx = idxT;
    res.sliceOnly = true;
    res.sliceIndex = z;
    res.sliceLabel = sprintf('Z %d/%d',z,Z);
    if signedBase && ~signedAtlas
        res.sourceNote = sprintf('Slice-specific FC for Z %d/%d; L/R labels preserved from full ROI table.',z,Z);
    else
        res.sourceNote = sprintf('True slice-specific FC: ROI time courses recomputed from selected Z slice only (Z %d/%d).',z,Z);
    end
catch
    res = resIn;
end
end

function name = localROINameFromBase(label,baseLabels,baseNames,s)
name = sprintf('ROI_%g',label);
try
    if ~isempty(baseLabels) && ~isempty(baseNames)
        ix = find(round(baseLabels) == round(double(label)),1,'first');
        if isempty(ix), ix = find(abs(round(baseLabels)) == abs(round(double(label))),1,'first'); end
        if ~isempty(ix) && ix <= numel(baseNames)
            nm = strtrim(char(baseNames{ix}));
            if ~isempty(nm), name = nm; return; end
        end
    end
catch
end
try
    if isfield(s,'opts') && isfield(s.opts,'roiNameTable')
        T = s.opts.roiNameTable;
        if isstruct(T) && isfield(T,'labels') && isfield(T,'names') && ~isempty(T.labels)
            labs = double(T.labels(:));
            ix = find(labs == double(label),1,'first');
            if isempty(ix), ix = find(abs(labs) == abs(double(label)),1,'first'); end
            if ~isempty(ix) && ix <= numel(T.names)
                nm = strtrim(char(T.names{ix}));
                if ~isempty(nm), name = sprintf('%s [%g]',nm,label); end
            end
        end
    end
catch
end
end

function tf = localIsBackground(label,name)
tf = false;
try
    if ~isfinite(label) || label == 0, tf = true; return; end
    n = lower(char(name));
    bad = {'background','outside','root','void','unknown'};
    for i = 1:numel(bad)
        if ~isempty(strfind(n,bad{i})), tf = true; return; end
    end
catch
    tf = false;
end
end

function R = localCorr(X)
X = double(X);
X = bsxfun(@minus,X,mean(X,1));
sd = std(X,0,1);
sd(sd <= 0 | ~isfinite(sd)) = 1;
X = bsxfun(@rdivide,X,sd);
R = (X' * X) ./ max(1,size(X,1)-1);
R = max(-1,min(1,R));
R(1:size(R,1)+1:end) = 1;
end

function B = localResizeNearest(A,Y,X)
A = double(A);
if isequal(size(A),[Y X]), B = A; return; end
try
    if exist('imresize','file') == 2
        B = imresize(A,[Y X],'nearest');
    else
        yy = round(linspace(1,size(A,1),Y));
        xx = round(linspace(1,size(A,2),X));
        B = A(yy,xx);
    end
catch
    yy = round(linspace(1,size(A,1),Y));
    xx = round(linspace(1,size(A,2),X));
    B = A(yy,xx);
end
end
