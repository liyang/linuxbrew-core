class Qscintilla2 < Formula
  desc "Port to Qt of the Scintilla editing component"
  homepage "https://www.riverbankcomputing.com/software/qscintilla/intro"
  url "https://www.riverbankcomputing.com/static/Downloads/QScintilla/2.11.6/QScintilla-2.11.6.tar.gz"
  sha256 "e7346057db47d2fb384467fafccfcb13aa0741373c5d593bc72b55b2f0dd20a7"
  license "GPL-3.0-only"
  revision 2

  livecheck do
    url "https://www.riverbankcomputing.com/software/qscintilla/download"
    regex(/href=.*?QScintilla(?:.gpl)?[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  bottle do
    sha256 cellar: :any, arm64_big_sur: "f83db677f22f7c346d5bec5d495554d217fd1ec6b850a24a32e7cc68959bd718"
    sha256 cellar: :any, big_sur:       "c49de115e2c7a0138db2370048ae40a68a9be05c68a9e47b21e740b1350dbef1"
    sha256 cellar: :any, catalina:      "fbc3cc9bef81993141bac96f05b7c9e277c2ac0a447c1ad23c45162fd54fba24"
    sha256 cellar: :any, mojave:        "20794671c986947c27acddf7d5770559ac1567a445b452a99af2669089493cc5"
  end

  depends_on "pyqt"
  depends_on "python@3.9"
  depends_on "qt@5"
  depends_on "sip"

  # Fix for rpath in library install name. Taken from
  # https://github.com/macports/macports-ports/pull/7790
  # https://www.riverbankcomputing.com/pipermail/qscintilla/2020-March/001444.html
  patch :DATA

  def install
    spec = (ENV.compiler == :clang) ? "macx-clang" : "macx-g++"
    spec << "-arm64" if Hardware::CPU.arm?
    args = %W[-config release -spec #{spec}]

    cd "Qt4Qt5" do
      inreplace "qscintilla.pro" do |s|
        s.gsub! "$$[QT_INSTALL_LIBS]", lib
        s.gsub! "$$[QT_INSTALL_HEADERS]", include
        s.gsub! "$$[QT_INSTALL_TRANSLATIONS]", prefix/"trans"
        s.gsub! "$$[QT_INSTALL_DATA]", prefix/"data"
        s.gsub! "$$[QT_HOST_DATA]", prefix/"data"
      end

      inreplace "features/qscintilla2.prf" do |s|
        s.gsub! "$$[QT_INSTALL_LIBS]", lib
        s.gsub! "$$[QT_INSTALL_HEADERS]", include
      end

      qt5 = Formula["qt@5"].opt_prefix
      system "#{qt5}/bin/qmake", "qscintilla.pro", *args
      system "make"
      system "make", "install"
    end

    # Add qscintilla2 features search path, since it is not installed in Qt keg's mkspecs/features/
    ENV["QMAKEFEATURES"] = prefix/"data/mkspecs/features"

    cd "Python" do
      (share/"sip").mkpath
      version = Language::Python.major_minor_version Formula["python@3.9"].opt_bin/"python3"
      pydir = "#{lib}/python#{version}/site-packages/PyQt5"

      args = ["--apidir=#{prefix}/qsci",
              "--destdir=#{pydir}",
              "--stubsdir=#{pydir}",
              "--qsci-sipdir=#{share}/sip",
              "--qsci-incdir=#{include}",
              "--qsci-libdir=#{lib}",
              "--pyqt=PyQt5",
              "--pyqt-sipdir=#{Formula["pyqt"].opt_share}/sip/Qt5",
              "--sip-incdir=#{Formula["sip"].opt_include}",
              "--no-dist-info"]

      # Only add compiler spec on macOS
      args << "--spec=#{spec}" if OS.mac?

      system Formula["python@3.9"].opt_bin/"python3", "configure.py", "-o", lib, "-n", include, *args

      system "make"
      system "make", "install"
      system "make", "clean"
    end
  end

  test do
    (testpath/"test.py").write <<~EOS
      import PyQt5.Qsci
      assert("QsciLexer" in dir(PyQt5.Qsci))
    EOS

    system Formula["python@3.9"].opt_bin/"python3", "test.py"
  end
end

__END__
diff --git a/Qt4Qt5/qscintilla.pro b/Qt4Qt5/qscintilla.pro
index 35b37da..7953c1b 100644
--- a/Qt4Qt5/qscintilla.pro
+++ b/Qt4Qt5/qscintilla.pro
@@ -37,10 +37,6 @@ CONFIG(debug, debug|release) {
     TARGET = qscintilla2_qt$${QT_MAJOR_VERSION}
 }

-macx:!CONFIG(staticlib) {
-    QMAKE_POST_LINK += install_name_tool -id @rpath/$(TARGET1) $(TARGET)
-}
-
 INCLUDEPATH += . ../include ../lexlib ../src

 !CONFIG(staticlib) {
