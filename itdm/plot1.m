function [] = plot1()

N = [4 5 6 7 8 9 10];
L = size(N);
Qtime = zeros(1,L(2));


%parfor (i = 1 : L(2), 7)
for i = 1 : L(2)
    %fprintf('hello from thread %d\n', i);
    [Throughput, queue_time, drop_packet_perc, Qtime(i)] = itdm(10000, N(i), 2, 3, 0.5, 1500);
    %fprintf('hello from thread %d\n', i);
end

plot(Qtime(1 : end), N(1:end), '-o');
xlabel('queue time');
ylabel('nodes');
end