function outData = HUMOR_pcaica_scope_output(originalData, decompData, scopeInfo)
outData = decompData;
if nargin < 3 || ~isstruct(scopeInfo) || ~isfield(scopeInfo,'sliceSpecific') || ~scopeInfo.sliceSpecific
    try, outData.pcaicaSliceScope = scopeInfo; catch, end
    return;
end
try
    Iorig = originalData.I;
    Iden  = decompData.I;
    if ndims(Iorig) ~= 4
        outData = decompData;
        outData.pcaicaSliceScope = scopeInfo;
        return;
    end
    Y = size(Iorig,1); X = size(Iorig,2); Z = size(Iorig,3); T = size(Iorig,4);
    z = max(1,min(Z,round(scopeInfo.zIndex)));
    Iden3 = reshape(Iden, [Y X T]);
    Iout = Iorig;
    Iout(:,:,z,:) = reshape(Iden3, [Y X 1 T]);
    outData = originalData;
    f = fieldnames(decompData);
    for ii = 1:numel(f)
        if strcmp(f{ii},'I'), continue; end
        outData.(f{ii}) = decompData.(f{ii});
    end
    outData.I = Iout;
    outData.pcaicaSliceScope = scopeInfo;
catch
    outData = decompData;
    try, outData.pcaicaSliceScope = scopeInfo; catch, end
end
end
