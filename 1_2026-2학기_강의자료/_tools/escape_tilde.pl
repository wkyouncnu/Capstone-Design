#!/usr/bin/perl
# 범위 물결표를 바로잡는다 — 두 방향 모두.
#
#   본문   ~  → \~   두 개가 한 문단에 있으면 marked · GitHub 가 그 사이를 취소선으로 그린다 (GFM ~text~)
#   코드  \~  →  ~   코드 블록·인라인 코드 안의 \~ 는 셸에서 글자 그대로의 ~ 가 되어 명령이 깨진다
#
# 코드 블록은 콜아웃 안(> ```)의 것도 코드로 본다. 2026-09-18 — 이것을 몰라서 콜아웃 안의
# `code ~/.bashrc` 가 `code \~/.bashrc` 로 바뀌었다. 닫히지 않은 펜스 하나(3주차 `ros2 run ...` 뒤의
# 백틱 한 개)가 그 뒤 전체의 코드/본문 판정을 뒤집기도 했다 → 펜스 개수가 홀수면 경고한다.
#
# 건드리지 않는 곳 — $수식$, $$블록 수식$$, ~~취소선~~.
# 사용:  perl escape_tilde.pl [--check] 파일...
use strict; use warnings;
my $check = 0;
if (@ARGV && $ARGV[0] eq '--check') { $check = 1; shift @ARGV; }
my $total = 0;
for my $f (@ARGV) {
  open(my $in, '<', $f) or die $f; my @L = <$in>; close $in;
  my ($fence, $mathblk, $n, $nf) = (0, 0, 0, 0);
  for my $l (@L) {
    if ($l =~ /^\s*(?:>\s*)*(```|~~~)/) { $fence = !$fence; $nf++; next; }
    if ($fence) {
      my $c = () = $l =~ /\\~/g;
      if ($c) { $l =~ s/\\~/~/g; $n += $c; }
      next;
    }
    if ($l =~ /^\s*(?:>\s*)*\$\$\s*$/) { $mathblk = !$mathblk; next; }
    next if $mathblk;
    my @parts = split /(`[^`]*`|\$\$[^\$]*\$\$|\$[^\$\n]+\$)/, $l;
    for my $p (@parts) {
      next if !defined $p || $p =~ /^\$/;
      if ($p =~ /^`/) {                       # 인라인 코드 — \~ 를 되돌린다
        my $c = () = $p =~ /\\~/g;
        if ($c) { $p =~ s/\\~/~/g; $n += $c; }
        next;
      }
      my $c = () = $p =~ /(?<![\\~])~(?!~)/g;
      if ($c) { $p =~ s/(?<![\\~])~(?!~)/\\~/g; $n += $c; }
    }
    $l = join('', grep { defined } @parts);
  }
  if ($nf % 2) { printf STDERR "경고  %s — 코드 펜스가 %d개(홀수). 닫히지 않은 블록이 있다\n", $f, $nf; $n++; }
  if ($n) {
    $total += $n;
    printf "%4d  %s\n", $n, $f;
    unless ($check) { open(my $out, '>', $f) or die $f; print $out @L; close $out; }
  }
}
print "합계 $total\n";
