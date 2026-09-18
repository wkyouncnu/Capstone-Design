#!/usr/bin/perl
# 본문의 범위 물결표 ~ 를 \~ 로 이스케이프한다.
# 두 개가 한 문단에 있으면 marked · GitHub 가 그 사이를 취소선으로 그린다 (GFM ~text~).
# 건드리지 않는 곳 — 코드 블록, `인라인 코드`, $수식$, $$블록 수식$$, 이미 \~ 인 것, ~~.
# 사용:  perl tilde.pl [--check] 파일...
use strict; use warnings;
my $check = 0;
if (@ARGV && $ARGV[0] eq '--check') { $check = 1; shift @ARGV; }
my $total = 0;
for my $f (@ARGV) {
  open(my $in, '<', $f) or die $f; my @L = <$in>; close $in;
  my ($fence, $mathblk, $n) = (0, 0, 0);
  for my $l (@L) {
    if ($l =~ /^\s*(```|~~~)/) { $fence = !$fence; next; }
    next if $fence;
    if ($l =~ /^\s*\$\$\s*$/) { $mathblk = !$mathblk; next; }
    next if $mathblk;
    # 코드 스팬과 수식을 떼어 두고 나머지만 고친다
    my @parts = split /(`[^`]*`|\$\$[^\$]*\$\$|\$[^\$\n]+\$)/, $l;
    for my $p (@parts) {
      next if !defined $p || $p =~ /^`/ || $p =~ /^\$/;
      my $c = () = $p =~ /(?<![\\~])~(?!~)/g;
      if ($c) { $p =~ s/(?<![\\~])~(?!~)/\\~/g; $n += $c; }
    }
    $l = join('', grep { defined } @parts);
  }
  if ($n) {
    $total += $n;
    printf "%4d  %s\n", $n, $f;
    unless ($check) { open(my $out, '>', $f) or die $f; print $out @L; close $out; }
  }
}
print "합계 $total\n";
