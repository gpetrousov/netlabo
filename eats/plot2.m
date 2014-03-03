function [] = plot2()

W = [2 3 4 5];
L = size(W);
Throughput = zeros(1,L(2));


%parfor (i = 1 : L(2), 7)
for i = 1 : L(2)
    %fprintf('hello from thread %d\n', i);
    [averageQtime, Throughput(i), drop_perc] = eatsv3( 10000, 10, W(i), 3, 0.5, 1500);
    %fprintf('hello from thread %d\n', i);
end

plot(Throughput(1 : end), W(1:end), '-o');
xlabel('Throughput');
ylabel('Channels');

end

