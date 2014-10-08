require 'formula'

class Asl < Formula
  url 'http://www.ampl.com/netlib/ampl/solvers.tgz'
  sha1 "f8046fc3378d513ecda1046d42bb255594920fd0"
  version "20141004"
  homepage 'http://www.ampl.com/hooking.html'

  option 'with-matlab', 'Build MEX file for use with Matlab'
  option 'with-mex-path=', 'Path to MEX executable, e.g., /Applications/Matlab/MATLAB_R2013b.app/bin/mex (default: mex)'

  resource 'spamfunc' do
    url 'http://netlib.org/ampl/solvers/examples/spamfunc.c'
    sha1 '429a79fc54facc5ef99219fe460280a883c75dfa'
  end

  def install
    ENV.universal_binary if OS.mac?
    cflags = %w[-I. -O -fPIC]

    if OS.mac?
      cflags += ["-arch", "#{Hardware::CPU.arch_32_bit}"]
      soname = "dylib"
      libtool_cmd = ["libtool", "-dynamic", "-undefined", "dynamic_lookup",
                      "-install_name", "#{lib}/libasl.#{soname}"]
    else
      soname = "so"
      libtool_cmd = ["ld", "-shared"]
    end

    # Dynamic libraries are more user friendly.
    (buildpath / 'makefile.brew').write <<-EOS.undent
      include makefile.u

      libasl.#{soname}: ${a:.c=.o}
      \t#{libtool_cmd.join(" ")} -o $@ $?

      libfuncadd0.#{soname}: funcadd0.o
      \t#{libtool_cmd.join(" ")} -o $@ $?
    EOS

    ENV.deparallelize
    targets = ["arith.h", "stdio1.h"]
    libs = ["libasl.#{soname}", "libfuncadd0.#{soname}"]
    system "make", "-f", "makefile.brew", "CC=#{ENV.cc}",
           "CFLAGS=#{cflags.join(' ')}", *(targets + libs)

    lib.install *libs
    (include / 'asl').install Dir["*.h"]
    (include / 'asl').install Dir["*.hd"]
    doc.install 'README'

    if build.with? "matlab"
      mex = ARGV.value("with-mex-path") || "mex"
      resource("spamfunc").stage do
        system mex, "-f", File.join(File.dirname(mex), "mexopts.sh"),
                    "-I#{include}/asl", "spamfunc.c", "-largeArrayDims",
                    "-L#{lib}", "-lasl", "-lfuncadd0", "-outdir", bin
      end
    end
  end

  def caveats
    s = <<-EOS.undent
      Include files are in #{include}/asl.
      To link with the ASL, you may simply use
      -L#{lib} -lasl -lfuncadd0
    EOS
    s += "\nAdd #{bin} to your MATLABPATH." if build.with? "matlab"
    s
  end
end
