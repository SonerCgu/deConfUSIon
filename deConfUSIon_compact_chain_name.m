function out = deConfUSIon_compact_chain_name(in)
% Clean user-facing dataset chain names without deleting scan IDs.
if nargin < 1 || isempty(in), in = 'dataset'; end
try, out = char(in); catch, out = 'dataset'; end

out = strrep(out,'...','_');
out = regexprep(out,'\.nii\.gz$','','ignorecase');
out = regexprep(out,'\.nii$','','ignorecase');
out = regexprep(out,'\.mat$','','ignorecase');
out = regexprep(out,'_0000[0-9a-fA-F]{4,}(?=_)','');
out = regexprep(out,'_[0-9a-fA-F]{8}(?=\.?$|_)','');
out = regexprep(out,'^preproc_preproc_','','ignorecase');
out = regexprep(out,'^preproc_','','ignorecase');

out = regexprep(out,'frame[_\-]?rej','frameRej','ignorecase');
out = regexprep(out,'framerej','frameRej','ignorecase');
out = regexprep(out,'temporalSmooth_','tsmooth_','ignorecase');
out = regexprep(out,'subsample_mean_','submean_','ignorecase');
out = regexprep(out,'subsample_median_','submed_','ignorecase');
out = regexprep(out,'imreg_median_n','imreg_med_n','ignorecase');
out = regexprep(out,'imregdemons_median_n','imregdemons_med_n','ignorecase');

out = regexprep(out,'Slice0*(\d+)of0*(\d+)','sl$1of$2','ignorecase');
out = regexprep(out,'slice0*(\d+)of0*(\d+)','sl$1of$2','ignorecase');
out = regexprep(out,'sl0*(\d+)of0*(\d+)','sl$1of$2','ignorecase');

for pass = 1:8
    ops = {'raw','frameRej','scrub','motor','preproc','filter','imreg','imregdemons','pca','ica','tsmooth','subsample','submean','submed'};
    for k = 1:numel(ops)
        out = regexprep(out,[ops{k} '_' ops{k}],ops{k},'ignorecase');
    end
end

out = regexprep(out,'raw_(?=.*(?:frameRej|scrub|despike|motor|pca|ica|imreg|BPF|LPF|HPF|tsmooth|sub))','','ignorecase');
out = regexprep(out,'[^A-Za-z0-9_\-\.]+','_');
out = regexprep(out,'_+','_');
out = regexprep(out,'^_+|_+$','');
if isempty(out), out = 'dataset'; end
end
