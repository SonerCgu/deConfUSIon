function atlas=fusiLightSuiteHistologyAtlas(cfg,targetSize,spacingMm)
% Block-average the published CCF2020 template without loading its 2.4 GB array.
file=fullfile(cfg.allenAtlas,'average_template_10.nii.gz');
assert(isfile(file),'deConfUSIon:LightSuiteHistologyMissing', ...
    'Install the Allen CCF2020 template with install_lightsuite_dependencies.ps1 -IncludeHistology, then export again.');
work=tempname;mkdir(work);
try
    files=gunzip(file,work);
catch err
    rmdir(work,'s');rethrow(err);
end
fid=fopen(files{1},'r','ieee-le');cleanup=onCleanup(@()finish(fid,work)); %#ok<NASGU>
assert(fid>=0,'Cannot open the Allen histology template.');
assert(fread(fid,1,'int32')==348,'Expected the published NIfTI-1 CCF2020 template.');
fseek(fid,40,'bof');dims=fread(fid,8,'int16')';
fseek(fid,70,'bof');datatype=fread(fid,1,'int16');bits=fread(fid,1,'int16');
fseek(fid,76,'bof');pixdim=fread(fid,8,'single')';
offset=fread(fid,1,'single');slope=fread(fid,1,'single');intercept=fread(fid,1,'single');
fseek(fid,123,'bof');units=fread(fid,1,'uint8');
assert(dims(1)==3&&datatype==512&&bits==16&&bitand(units,7)==2, ...
    'Expected the published 3-D uint16 CCF2020 template in millimetres.');
shape=double(dims(2:4));factor=shape./double(targetSize);
assert(all(factor>=1&factor==round(factor))&& ...
    all(abs(double(pixdim(2:4)).*factor-double(spacingMm))<1e-6), ...
    'deConfUSIon:LightSuiteHistologyGrid','The CCF2020 template and vascular atlas must share the AP/DV/ML extent.');
if slope==0,slope=1;intercept=0;end
assert(all(isfinite([slope intercept])),'Invalid histology intensity scaling.');
fseek(fid,offset,'bof');atlas=zeros(targetSize,'single');
for z=1:targetSize(3)
    plane=zeros(targetSize(1:2),'single');
    for j=1:factor(3)
        slab=fread(fid,prod(shape(1:2)),'*uint16');
        assert(numel(slab)==prod(shape(1:2)),'Incomplete CCF2020 template.');
        slab=reshape(single(slab),[factor(1) targetSize(1) factor(2) targetSize(2)]);
        plane=plane+reshape(sum(sum(slab,1),3),targetSize(1:2));
    end
    atlas(:,:,z)=plane./prod(factor)*slope+intercept;
end
end

function finish(fid,work)
if fid>=0,fclose(fid);end
if isfolder(work),rmdir(work,'s');end
end
