%deserialize_data parses a json string into Matlab data structures
% It is based on the project transplant written by Bastian Bechtold (c) 2014.
% It uses a moddified version of the parsejson function from the transplant
% project.
% deserialize_data(STRING)
%    reads STRING as JSON data, and creates Matlab data structures
%    from it. It decodes the SciSerialize format deffinied on 
%    https://github.com/SciSerialize/Definition. The supported data types
%    are datetime, timedelta(in matlab duration) and N dimensional arrays
%    (converted to matlab matrix). For details see the deffinition webpage.
%
%    
%
%    This is a complete implementation of the JSON spec, and invalid
%    data will generally throw errors.

% (c) 2015 Nils L. Westhausen
% This code is licensed under the BSD 3-clause license

function [obj] = deserialize_data(data)
try
    map = parsejson(data);
catch
    error(['Parsing json-data failed']);
end

    try
        obj = type_decoder(map);
        
    catch
        error(['Type ' map('__type__') ...
            ' is not implemented in sciserialize matlab yet']);
    end
end

function [obj] = type_decoder(map)
if isKey(map, '__type__')
    if strcmp(map('__type__'), 'datetime')
        obj = datetime_decoder(map);
    elseif strcmp(map('__type__'), 'timedelta')
          obj = timedelta_decoder(map);
    elseif strcmp(map('__type__'), 'ndarray')
        obj = nd_array_decoder(map);
    else
        error(['Type ' map('__type__') ...
            ' is not implemented in sciserialize matlab yet'])   
    end
end   
end

% decodes datetimes to the matlab datetime class
function obj = datetime_decoder(map)
t = map('isostr');
if isempty(regexp(t, '\d\d:\d\d:\d\d\.\d', 'match'))
    t = regexprep(t, '(\d\d:\d\d:\d\d)', '$1\.0');
end
out = regexp(t(end-5:end), '([-+]\d\d(:\d\d)?)|Z', 'match');
if isempty(out)
    obj = datetime(t, ...
    'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSSS', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSS');
else
    zone = out{1};
    obj = datetime(t, ...
    'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSSSXXX', ...
    'TimeZone', zone, ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSSXXX');
end

end

% decodes time-delta to the matlab duration class
function obj = timedelta_decoder(map)
    % all of this types are of the class duration
    day = days(map('days'));
    second = seconds(map('seconds'));
    millisec = duration(0,0,0,(map('microsec')/10^6));
    obj = day + second + millisec;
end

% decodes nd-arrays to n dimensional matlab matrixes
function obj = nd_array_decoder(map)
bytes = map('bytes');
        binary = base64decode(bytes('__base64__'));
        dtype = map('dtype');
        dim = cell2mat(map('shape'));
        if length(dim) == 1
            dim = [1 dim];
        end
        % translate numpy dtypes into Matlab class names
        if strcmp(dtype, 'complex128')
            data = typecast(binary, 'double')';
            data = data(1:2:end) + 1i*data(2:2:end);
        elseif strcmp(dtype, 'float64')
            data = typecast(binary, 'double')';
        elseif strcmp(dtype, 'complex64')
            data = typecast(binary, 'single')';
            data = data(1:2:end) + 1i*data(2:2:end);
        elseif strcmp(dtype, 'float32')
            data = typecast(binary, 'single')';
        elseif strcmp(dtype, 'bool')
            data = logical(binary);
        else
            data = typecast(binary, dtype);
        end
        data = reshape(data, fliplr(dim));
        

        if length(dim) > 2
            obj = permute(data,[2 1 3:length(dim)]); 
        else
            obj = permute(data,[2 1]);
        end
end