function success = shutdownADRV(ip, user, password)
% shutdownADRV Sends a 'shutdown now' command to a remote Linux board via SSH.
%
% Usage:
%   success = shutdownRemoteBoard('192.168.1.10', 'root', 'analog')

    if nargin < 1, ip = '192.168.1.10'; end
    if nargin < 2, user = 'root'; end
    if nargin < 3, password = 'analog'; end

    success = false;
    fprintf('Connecting to %s via SSH...\n', ip);

    try
        % Create the SSH connection object
        s = ssh(ip, 'User', user, 'Password', password);
        
        % Execute the shutdown command
        fprintf('Sending shutdown command...\n');
        execute(s, 'sudo shutdown now');
        
        fprintf('Command accepted. The board is shutting down.\n');
        success = true;
    catch ME
        fprintf('Failed to shutdown the board.\n');
        fprintf('Error Message: %s\n', ME.message);
    end
end