function s = buildFooterLabel()
person = 'Soner Caner Cagun';
tool = 'deConfUSIon';
inst = 'Max-Planck Institute for Biological Cybernetics';
dt = datestr(now,'yyyy-mm-dd HH:MM');
s = sprintf('%s - %s - %s - %s', person, tool, inst, dt);
end
