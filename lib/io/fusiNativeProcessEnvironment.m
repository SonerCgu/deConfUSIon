function fusiNativeProcessEnvironment(builder,executableFolder,platform)
% Clean only a child process's environment, never MATLAB's environment.
% Native Unix registration tools must not load MATLAB's Qt/C++ libraries.
if nargin<3,platform='unix';if ispc,platform='win';end,end
if any(strcmpi(platform,{'win','windows'})),return;end
environment=builder.environment();iterator=environment.keySet().iterator();names={};
while iterator.hasNext(),names{end+1}=char(iterator.next());end %#ok<AGROW>
for k=1:numel(names)
    if startsWith(upper(names{k}),'QT_')||startsWith(upper(names{k}),'QML')
        environment.remove(names{k});
    end
end
for name={'PATH','LD_LIBRARY_PATH','DYLD_LIBRARY_PATH','DYLD_FRAMEWORK_PATH'}
    value=environment.get(name{1});if isempty(value),continue;end
    entries=strsplit(char(value),pathsep);
    entries=entries(~contains(entries,matlabroot));
    if strcmp(name{1},'PATH')&&~isempty(executableFolder)
        entries=[{char(executableFolder)} entries]; %#ok<AGROW>
    end
    if isempty(entries),environment.remove(name{1});
    else,environment.put(name{1},strjoin(entries,pathsep));end
end
end
