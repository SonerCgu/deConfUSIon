function results=run_deConfUSIon_tests(selection)
% Run named tests after initializing active module paths.
root=deConfUSIon_setup();
if nargin<1,selection=fullfile(root,'tests');end
results=runtests(selection);disp(table(results));
assert(all([results.Passed]),'deConfUSIon:TestsFailed','Some selected tests failed or were incomplete.');
end
