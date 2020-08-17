#!/bin/bash

# Compile to LaTeX based on a company-wide template
# Created by Jacob Strieb
# June 2020

set -e

# Look for pandoc.exe and pdflatex.exe, if they don't exist, look for
# non-Windows versions. If neither exists, they are not on the PATH, and the
# program cannot continue.
PANDOC=pandoc.exe
if ! which "$PANDOC" > /dev/null; then
  PANDOC=pandoc
  if ! which "$PANDOC" > /dev/null; then
    echo "Pandoc is required in order to compile the document."
    echo "Add Pandoc to the PATH or modify $0 to use the correct pandoc binary."
    exit
  fi
fi
PDFLATEX=pdflatex.exe
if ! which "$PDFLATEX" > /dev/null; then
  PDFLATEX=pdflatex
  if ! which "$PDFLATEX" > /dev/null; then
    echo "pdfLaTeX is required in order to compile the document."
    echo "Add pdfLaTeX to the PATH or modify $0 to use the correct pdfLaTeX binary."
    exit
  fi
fi

# Echo usage if the user asks for help
if echo "$1" \
  | grep --ignore-case --quiet "^\-h$\|^\-\-help$"; then
  echo "Usage: $0 <infile.md>"
  echo "   or  $0 <Google Docs URL> \"<title>\" \"[author]\" \"[date]\""
  echo "   or  $0 <infile.*> \"<title>\" \"<author>\" \"<date>\""
  exit
fi

# Make sure we have a template.tex and logo.png file in the current direcotry
if [ ! -f "template.tex" ]; then
  curl --location --output "template.tex" \
    "https://github.com/Genrep-Software/document-template/raw/master/template.tex"
fi
if [ ! -f "logo.png" ]; then
  curl --location --output "logo.png" \
    "https://github.com/Genrep-Software/document-template/raw/master/logo.png"
fi

# If the input is a Google docs/drive URL, handle and exit
if echo "$1" \
  | grep --ignore-case --quiet \
    "^https\?:\/\/[a-z]*\.google\.com\/document\/d\/"; then
  if [ -z "$2" ]; then
    echo "Usage: $0 <infile.md>"
    echo "   or  $0 <Google Docs URL> \"<title>\" \"[author]\" \"[date]\""
    echo "   or  $0 <infile.*> \"<title>\" \"<author>\" \"<date>\""
    exit
  fi
  DOC_TITLE="$2"
  DOC_AUTHOR="Genrep Software, LLC."
  if [ -n "$3" ]; then
    DOC_AUTHOR="$3"
  fi
  DOC_DATE="$(date +'%A, %B %d, %Y')"
  if [ -n "$4" ]; then
    DOC_DATE="$4"
  fi

  EXPORT_FORMAT="docx"

  # Generate an export URL
  echo "Generating export URL..."
  EXPORT_URL="$(echo $1 | grep -o --ignore-case \
    '^https\?:\/\/[a-z]*\.google\.com\/document\/d\/[a-z0-9\_-]*\/')""export?format=$EXPORT_FORMAT"
  echo "Exporting from $EXPORT_URL..."

  OUTFILE="out.tex"
  TEMPFILE="out-temp.tex"
  INFILE="in.$EXPORT_FORMAT"

  # Download the document
  curl --output "$INFILE" --location "$EXPORT_URL"

  # Convert to LaTeX
  $PANDOC \
    --extract-media "." \
    --template "template.tex" \
    --metadata title:"$DOC_TITLE" \
    --metadata author:"$DOC_AUTHOR" \
    --metadata date:"$DOC_DATE" \
    "$INFILE" \
    --output "$TEMPFILE"

  # FIXME: this needs to be improved
  # Strip unnecessary quote environments
  cat "$TEMPFILE" \
    | sed "/\\\\\(begin\|end\){quote}/d" > "$OUTFILE"

  # Compile LaTeX to PDF -- do it twice for TOC update purposes
  $PDFLATEX "$OUTFILE"
  $PDFLATEX "$OUTFILE"

  # Clean up
  cp "out.pdf" "$DOC_TITLE.pdf"
  rm in.* out.*
  # find . -name "in*" | xargs rm
  # find . -name "out*" | xargs rm

  exit
fi

# Set the input and output file based on command-line arguments
INFILE="README.md"
if [ -n "$1" ]; then
  INFILE="$1"
else
  echo "Please specify an input file to convert!"
  echo
  echo "Usage: $0 <infile.md>"
  echo "   or  $0 <Google Docs URL> \"<title>\" \"[author]\" \"[date]\""
  echo "   or  $0 <infile.*> \"<title>\" \"<author>\" \"<date>\""
  echo
  echo "Defaulting to \"README.md\"..."
fi
# Strip everything from the last period to the end of the string (inclusive)
OUTFILE="$(echo $INFILE | sed 's/\(.*\)\.[^\.]*$/\1/')"".tex"

# Get additional arguments for metadata if not Markdown based on extracting the
# file extension
if echo $INFILE \
  | sed 's/.*\.\([^\.]*\)$/\1/' \
  | grep --ignore-case --quiet md; then
  # Assume there is metadata in the file if it is Markdown
  # Output TeX file
  $PANDOC \
    --template=template.tex \
    "$INFILE" \
    --output "$OUTFILE"
else
  # If not Markdown, look for title, author, and date arguments (respectively)
  if [ "$#" -eq 4 ]; then
    # Output TeX file
    $PANDOC \
      --template=template.tex \
      --metadata title:"$2" \
      --metadata author:"$3" \
      --metadata date:"$4" \
      "$INFILE" \
      --output "$OUTFILE"
  else
    echo "Please specify the title, author, and date in quotes!"
    echo
    echo "Usage: $0 <infile.md>"
    echo "   or  $0 <Google Docs URL> \"<title>\" \"[author]\" \"[date]\""
    echo "   or  $0 <infile.*> \"<title>\" \"<author>\" \"<date>\""
    exit
  fi
fi

# Compile LaTeX to PDF -- do it twice for TOC update purposes
$PDFLATEX "$OUTFILE"
$PDFLATEX "$OUTFILE"
