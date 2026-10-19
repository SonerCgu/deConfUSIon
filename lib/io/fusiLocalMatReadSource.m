function [readFile,cached,cacheState] = fusiLocalMatReadSource(file,progress,options)
% Stage large network MAT files with sequential I/O before HDF5 reads.
% The source is never changed. Cache identity includes path, size and mtime;
% only a completely copied, verified file is published in our temp folder.
% options.force/cacheRoot allow isolated fixtures and diagnostics.
if nargin<2, progress=[]; end
if nargin<3, options=struct(); end
readFile=file; cached=false;cacheState='direct';
info=dir(file); if isempty(info)||info(1).isdir, return; end
network=startsWith(char(file),'\\');
if ispc && ~network
    try
        drive=System.IO.DriveInfo(System.IO.Path.GetPathRoot(char(file)));
        network=strcmp(char(drive.DriveType.ToString()),'Network');
    catch
        % Optional cache: unsupported drive discovery must not block loading.
    end
end
force=isfield(options,'force')&&options.force;
if ~force && (~network||info(1).bytes<128*1024^2), return; end
folder=fullfile(tempdir,'deConfUSIon_read_cache');
if isfield(options,'cacheRoot'), folder=options.cacheRoot; end
temporary='';
try
    if ~isfolder(folder), mkdir(folder); end
    identity=char(file);
    if ispc,identity=char(System.IO.Path.GetFullPath(identity));end
    key=sprintf('%s|%.0f|%.15g',identity,info(1).bytes,info(1).datenum);
    md=java.security.MessageDigest.getInstance('SHA-256');md.update(unicode2native(key,'UTF-8'));
    digest=typecast(md.digest(),'uint8');key=lower(reshape(dec2hex(digest,2).',1,[]));
    destination=fullfile(folder,[key '.mat']);
    existing=dir(destination);
    if ~isempty(existing)&&existing.bytes==info(1).bytes
        readFile=destination;cached=true;cacheState='reused';
        % Evict least recently used copies, rather than an old but actively
        % reused scan. This only changes our private cache file's timestamp.
        try
            localCopy=java.io.File(destination);localCopy.setLastModified(java.lang.System.currentTimeMillis());
        catch
        end
        if ~isempty(progress), progress(1,'Using local copy of network MAT file...'); end
        return;
    end
    % Baseline/metadata readers can reuse an existing copy without causing a
    % multi-GB transfer just to inspect a short time window or a header.
    if isfield(options,'existingOnly')&&options.existingOnly,return;end
    % Leave working space on the local disk and fall back to the source if
    % staging is unavailable. Do not touch analysis saves or unrelated files.
    if java.io.File(folder).getUsableSpace()<info(1).bytes+512*1024^2, return; end
    pruneCache(folder,max(0,8*1024^3-info(1).bytes),destination);
    temporary=[tempname(folder) '.partial'];
    copySequential(file,temporary,info(1).bytes,progress);
    after=dir(file);copied=dir(temporary);
    if isempty(after)||after.bytes~=info(1).bytes||after.datenum~=info(1).datenum|| ...
            isempty(copied)||copied.bytes~=info(1).bytes
        error('deConfUSIon:ReadCacheChanged','Source changed or network copy was incomplete.');
    end
    [ok,message]=movefile(temporary,destination,'f');
    if ~ok, error('deConfUSIon:ReadCachePublish','%s',message); end
    readFile=destination;cached=true;cacheState='staged';
catch ME
    if ~isempty(temporary)&&isfile(temporary), delete(temporary); end
    if any(strcmp(ME.identifier,{'deConfUSIon:ProcessingCancelled','deConfUSIon:DecompositionCancelled'})), rethrow(ME); end
    warning('deConfUSIon:ReadCache','Local read cache unavailable; reading source directly: %s',ME.message);
end
end

function copySequential(source,destination,bytes,progress)
input=fopen(source,'rb');if input<0,error('deConfUSIon:ReadCacheOpen','Cannot read %s',source);end
inputGuard=onCleanup(@()fclose(input)); %#ok<NASGU>
output=fopen(destination,'wb');if output<0,error('deConfUSIon:ReadCacheOpen','Cannot create local read cache.');end
outputGuard=onCleanup(@()fclose(output)); %#ok<NASGU>
done=0;
if ~isempty(progress),progress(0,'Copying network MAT file to local read cache...');end
while done<bytes
    block=fread(input,min(64*1024^2,bytes-done),'*uint8');
    if isempty(block),error('deConfUSIon:ReadCacheShort','Network read ended before the file was complete.');end
    written=fwrite(output,block,'uint8');
    if written~=numel(block),error('deConfUSIon:ReadCacheWrite','Local cache write was incomplete.');end
    done=done+written;
    if ~isempty(progress),progress(done/bytes,sprintf('Copying network MAT: %.0f / %.0f MB',done/1024^2,bytes/1024^2));end
end
end

function pruneCache(folder,budget,current)
files=dir(fullfile(folder,'*.mat'));[~,order]=sort([files.datenum],'descend');used=0;
for k=order
    file=fullfile(files(k).folder,files(k).name);
    % Only this helper's SHA256 names belong to this cache.
    if isempty(regexp(files(k).name,'^[a-f0-9]{64}\.mat$','once'))||strcmp(file,current),continue;end
    used=used+files(k).bytes;
    if used>budget,try,delete(file);catch,end,end
end
end
