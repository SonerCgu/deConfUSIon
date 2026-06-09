function tag = deConfUSIon_pcaica_scope_tag(scopeInfo)
tag = '';
try
    if isstruct(scopeInfo) && isfield(scopeInfo,'sliceSpecific') && scopeInfo.sliceSpecific
        tag = sprintf('sl%03dof%03d', round(scopeInfo.zIndex), round(scopeInfo.nSlices));
    end
catch
    tag = '';
end
end
