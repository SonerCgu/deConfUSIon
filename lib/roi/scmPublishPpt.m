function scmPublishPpt(stagedPath, finalPath, expectedSlides)
%SCMPUBLISHPPT Publish a complete SCM presentation without replacing old work.
% The writer stages beside the final destination so a failed write never
% appears as a completed PPT and publication can use a same-volume move.
validateattributes(expectedSlides, {'numeric'}, {'scalar','integer','positive','finite'});
if exist(finalPath,'file') == 2 || exist(finalPath,'dir') == 7
    error('SCM:PptExists','The PowerPoint destination already exists: %s',finalPath);
end
if exist(stagedPath,'file') ~= 2
    error('SCM:PptIncomplete','PowerPoint did not create its output file.');
end
try
    package = java.util.zip.ZipFile(java.io.File(stagedPath));
    closePackage = onCleanup(@()package.close()); %#ok<NASGU>
    if isempty(package.getEntry('[Content_Types].xml')) || isempty(package.getEntry('ppt/presentation.xml'))
        error('SCM:PptIncomplete','The exported file is not a complete PowerPoint package.');
    end
    entries = package.entries();
    nSlides = 0;
    while entries.hasMoreElements()
        entry = entries.nextElement();
        if ~isempty(regexp(char(entry.getName()), '^ppt/slides/slide[0-9]+\.xml$', 'once'))
            nSlides = nSlides + 1;
        end
    end
    if nSlides ~= expectedSlides
        error('SCM:PptIncomplete','PowerPoint contains %d slides; %d were requested.',nSlides,expectedSlides);
    end
    clear closePackage; % Release Windows' file handle before renaming.
catch ME
    failure = MException('SCM:PptIncomplete','PowerPoint export was not published: %s',ME.message);
    throw(addCause(failure,ME));
end
source = java.io.File(stagedPath);
destination = java.io.File(finalPath);
% No REPLACE_EXISTING: also protects against a destination created since the
% initial check (e.g. a second viewer exporting at the same time).
java.nio.file.Files.move(source.toPath(), destination.toPath(), javaArray('java.nio.file.CopyOption',0));
end
