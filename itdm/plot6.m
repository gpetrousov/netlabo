function [] = plot5()

Lambda = [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1];
L = size(Lambda);
drop_perc = zeros(1,L(2));


%parfor (i = 1 : L(2), 7)
for i = 1 : L(2)
    %fprintf('hello from thread %d\n', i);
    [Throughput, queue_time, drop_packet_perc, Qtime, drop_perc(i)] = itdm(10000, 10, 5, 3, Lambda(i), 1500);
    %fprintf('hello from thread %d\n', i);
end

plot(drop_perc(1 : end), Lambda(1:end), '-o');
xlabel('drop_perc');
ylabel('Lambda');
end