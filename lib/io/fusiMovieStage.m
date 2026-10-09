function stage=fusiMovieStage(files)
% Keep the Windows MPEG-4 encoder off long paths and network shares.
% Final files still belong to the selected analysed-data export directory.
if ischar(files)||isstring(files),files=cellstr(files);end
scratch=getpref('deConfUSIon','movieScratchFolder','');
if isempty(scratch),scratch=fullfile(deConfUSIon_root(),'.deconfusion-cache','MovieExports');end
[ok,~]=mkdir(scratch);
if ~ok,scratch=fullfile(tempdir,'deConfUSIonMovieExports');[ok,message]=mkdir(scratch);end
if ~ok,error('deConfUSIon:MovieScratch','Cannot create a movie encoding folder: %s',message);end
folder=tempname(scratch);mkdir(folder);work=cell(size(files));preserve=false;
for k=1:numel(files)
    destination=fileparts(files{k});
    if ~isfolder(destination),[ok,message]=mkdir(destination);if ~ok,error('deConfUSIon:MovieFolder','Cannot create %s: %s',destination,message);end,end
    work{k}=fullfile(folder,sprintf('movie_%02d.mp4',k));
end
stage=struct('files',{work},'commit',@commit,'cleanup',@cleanup);
    function commit()
        % Java NIO uses Unicode Windows paths, including paths that exceed
        % the legacy encoder / command-shell limit. No shell copy command.
        try
            for j=1:numel(files)
                source=java.io.File(work{j});target=java.io.File(files{j});
                options=javaArray('java.nio.file.CopyOption',1);
                options(1)=java.nio.file.StandardCopyOption.REPLACE_EXISTING;
                java.nio.file.Files.copy(source.toPath(),target.toPath(),options);
                if target.length()~=source.length(),error('Incomplete movie copy.');end
            end
        catch ME
            preserve=true;
            error('deConfUSIon:MovieTransfer','Movie transfer failed: %s. Encoded movies retained in %s.',ME.message,folder);
        end
        cleanup();
    end
    function cleanup()
        if preserve||~isfolder(folder),return;end
        try
            for j=1:numel(work),if isfile(work{j}),delete(work{j});end,end
            rmdir(folder); % Only our own empty, uniquely created staging folder.
        catch
            % An encoder may still hold a file during exception unwinding.
            % Do not replace the original export error with a cleanup error.
        end
    end
end
