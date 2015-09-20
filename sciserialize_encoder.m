%sciserialize_encoder encodes Matlab datatypes to json by the difinition of
%the sciserialize project. It is based on the DUMPJSON function of the
%project transplant written by Bastian Bechtold.
%
%DUMPJSON dumps Matlab data as a JSON string
% DUMPJSON(DATA)
%    recursively walks through DATA and creates a JSON string from it.
%    - strings are converted to strings with escape sequences
%    - scalars are converted to numbers
%    - logicals are converted to `true` and `false`
%    - arrays are converted to arrays of numbers
%    - matrices are converted to arrays of arrays of numbers
%    - [] is converted to null
%    - cell arrays are converted to arrays
%    - cell matrices are converted to arrays of arrays
%    - structs are converted to objects
%    - struct arrays are converted to arrays of objects
%    - function handles and matlab objects will raise an error.
%
%    In contrast to may other JSON parsers, this one does not try
%    special-case numeric matrices. Also, this correctly transplates
%    escape sequences in strings.

% (c) 2014 Bastian Bechtold
% This code is licensed under the BSD 3-clause license

function [json] = sciserialize_encoder(data)
    if numel(data) > 10000
       warning('JSON:dump:toomuchdata', ...
               'dumping big data structures to JSON might take a while')
    end
    json = value(data);
end

% dispatches based on data type
function [json] = value(data)
    try
        
        if any(size(data) == 0)
            json = null(data);
        elseif isnumeric(data) && any(size(data) > 1)
            json = encode_nd_array(data);
        else
            
            if ischar(data)
                json = string(data);
            elseif iscell(data)
                json = cell(data);
            elseif isa(data , 'containers.Map')
                json = map(data);
            elseif isa(data , 'duration')
                json = encode_duration(data);
            elseif isa(data , 'datetime')
                json = encode_datetime(data);
            elseif any(size(data) > 1)
                json = array(data);
            elseif isstruct(data)
                json = struct(data);
            elseif isscalar(data)
                
                if islogical(data)
                    json = logical(data);
                elseif isnumeric(data)
                    json = number(data);
                else
                    
                    error();
                end
            end
        end
    catch err
        error('JSON:dump:unknowntype', ...
              ['can''t encode ' ' (' class(data) ') as JSON']);
    end
end

% dumps a string value as a string
function [json] = string(data)
    data = strrep(data, '\', '\\');
    data = strrep(data, '"', '\"');
    data = strrep(data, '/', '\/');
    data = strrep(data, sprintf('\b'), '\b');
    data = strrep(data, sprintf('\f'), '\f');
    data = strrep(data, sprintf('\n'), '\n');
    data = strrep(data, sprintf('\r'), '\r');
    data = strrep(data, sprintf('\t'), '\t');
    % convert non-ASCII characters to `\uXXXX` sequences, where XXX is
    % the hex unicode codepoint of the character.
    data = regexprep(data, '([^\x00-\x7F])', '\\u${sprintf(''%04s'', dec2hex($1))}');
    json = sprintf('"%s"', data);
end

% dumps a numeric value as a number
function [json] = number(data)
    if isinteger(data)
        json = sprintf('%i', data);
    else
        json = sprintf('%.50g', data);
    end
end

% dumps a logical value as `true` or `false`
function [json] = logical(data)
    if data
        json = 'true';
    else
        json = 'false';
    end
end

% dumps an n-dimensional value as a cell array of (n-1)-D values
function [json] = multidim(data)
    % convert 2x3x4 into {1x3x4, 1x3x4}
    cell = num2cell(data, 2:(ndims(data)));
    % convert {1x3x4, 1x3x4} into {3x4, 3x4}
    for idx=1:length(cell)
        cell{idx} = shiftdim(cell{idx}, 1);
    end
    json = value(cell);
end

% dumps a one-dimensional array of values as an array
function [json] = array(data)
    json = '[';
    for idx=1:length(data)
        json = [json value(data(idx))];
        if idx < length(data)
            json = [json ','];
        end
    end
    json = [json ']'];
end

% dumps a one-dimensional cell array of values as an array
function [json] = cell(data)
    json = '[';
    for idx=1:length(data)
        json = [json value(data{idx})];
        if idx < length(data)
            json = [json ','];
        end
    end
    json = [json ']'];
end

% dumps a 0-dimensional struct as an object
function [json] = struct(data)
    json = '{';
    keys = fieldnames(data);
    for idx=1:length(keys)
        key = keys{idx};
        json = [json value(key) ':' value(data.(key))];
        if idx < length(keys)
            json = [json ','];
        end
    end
    json = [json '}'];
end

% dumps a map as an object
function [json] = map(data)
    json = '{';
    keies = keys(data);
    for idx=1:length(keies)
        key = keies{idx};
        json = [json value(key) ':' value(data(key))];
        if idx < length(keies)
            json = [json ','];
        end 
    end
    json = [json '}'];
end

% dumps `null`
function [json] = null(~)
    json = 'null';
end

function [json] = encode_nd_array(data)
    if ~isreal(data) && isinteger(data)
        data = double(data); % Numpy does not know complex int
    end
    % convert to uint8 1-D array in row-major order
    dim = size(data);
    if isreal(data)
        if length(dim) > 2
            data = permute(data,[2 1 3:length(dim)]);
        else
            data = permute(data, [2 1]);
        end
        binary = typecast(data(:), 'uint8');
    else
        % convert [complex, complex] into [real, imag, real, imag]
        tmp = zeros(numel(data)*2, 1);
        if isa(data, 'single')
            tmp = single(tmp);
        end
        
        if length(dim) > 2
            data = permute(data,[2 1 3:length(dim)]);
        else
            data = permute(data, [2 1]);
        end
        tmp(1:2:end) = real(data(:));
        tmp(2:2:end) = imag(data(:));
        binary = typecast(tmp, 'uint8');
    end
    if islogical(data)
        % convert logicals (bool) into one-byte-per-bit
        
        if length(dim) > 2
            data = permute(data,[2 1 3:length(dim)]);
        else
            data = permute(data, [2 1]);
        end
        binary = cast(data,'uint8');
    end
    base64 = base64encode(binary);
    % translate Matlab class names into numpy dtypes
    if isa(data, 'double') && isreal(data)
        dtype = 'float64';
    elseif isa(data, 'double')
        dtype = 'complex128';
    elseif isa(data, 'single') && isreal(data)
        dtype = 'float32';
    elseif isa(data, 'single')
        dtype = 'complex64';
    elseif isa(data, 'logical')
        dtype = 'bool';
    elseif isinteger(data)
        dtype = class(data);
    else
        return % don't encode
    end
    
    nd_size = num2cell(fliplr(size(data)));
    base64 = containers.Map('__base64__',base64);
    keys = {'shape', 'dtype', 'bytes', '__type__'};
    values = {nd_size, dtype, base64, 'ndarray'};
    map = containers.Map(keys, values);
    json = value(map);
end

function [json] = encode_datetime(data)
     %data.Format = 'yyyy-MM-dd''T''HH:mm:ss.SSSS';
     date_string =  char(data,'yyyy-MM-dd''T''HH:mm:ss.SSSS');
     time_zone = data.TimeZone;
     keys = {'isostr', '__type__'};
     values = {[date_string time_zone], 'datetime'};
     map = containers.Map(keys, values);
     json = value(map);
end

function [json] = encode_duration(data)
    %delta_str = char(data, 'hh:mm:ss.SSSSSS');
    date_vec = datevec(data);
    days = date_vec(2) * 365 + date_vec(3);
    seconds = date_vec(4) * 3600 + date_vec(5) * 60 + fix(date_vec(6));
    micro_seconds = round(mod(date_vec(6), 1) * 10^6);
    keys = {'days', 'seconds', 'microsec', '__type__'};
    values = {days, seconds, micro_seconds, 'timedelta'};
    map = containers.Map(keys, values);
    json = value(map);
end