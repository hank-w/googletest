#!/bin/bash
# Testing Memes

set -euox pipefail

readonly LINUX_LATEST_CONTAINER="gcr.io/google.com/absl-177019/linux_hybrid-latest:20201008"
readonly LINUX_GCC_FLOOR_CONTAINER="gcr.io/google.com/absl-177019/linux_gcc-floor:20201015"

if [[ -z ${GTEST_ROOT:-} ]]; then
  GTEST_ROOT="$(realpath $(dirname ${0})/..)"
fi

if [[ -z ${STD:-} ]]; then
  STD="c++11 c++14 c++17 c++20"
fi

# Test the CMake build
for cc in /usr/local/bin/gcc /opt/llvm/clang/bin/clang; do
  for cmake_off_on in OFF ON; do
    time docker run \
      --volume="${GTEST_ROOT}:/src:ro" \
      --tmpfs="/build:exec" \
      --workdir="/build" \
      --rm \
      --env="CC=${cc}" \
      --env="CXX_FLAGS=\"-Werror -Wdeprecated\"" \
      ${LINUX_LATEST_CONTAINER} \
      /bin/bash -c "
        cmake /src \
          -DCMAKE_CXX_STANDARD=11 \
          -Dgtest_build_samples=ON \
          -Dgtest_build_tests=ON \
          -Dgmock_build_tests=ON \
          -Dcxx_no_exception=${cmake_off_on} \
          -Dcxx_no_rtti=${cmake_off_on} && \
        make -j$(nproc) && \
        ctest -j$(nproc) --output-on-failure"
  done
done

# Do one test with an older version of GCC
time docker run \
  --volume="${GTEST_ROOT}:/src:ro" \
  --workdir="/src" \
  --rm \
  --env="CC=/usr/local/bin/gcc" \
  ${LINUX_GCC_FLOOR_CONTAINER} \
    /usr/local/bin/bazel test ... \
      --copt="-Wall" \
      --copt="-Werror" \
      --copt="-Wno-error=pragmas" \
      --keep_going \
      --show_timestamps \
      --test_output=errors

# Test GCC
for std in ${STD}; do
  for absl in 0 1; do
    time docker run \
      --volume="${GTEST_ROOT}:/src:ro" \
      --workdir="/src" \
      --rm \
      --env="CC=/usr/local/bin/gcc" \
      --env="BAZEL_CXXOPTS=-std=${std}" \
      ${LINUX_LATEST_CONTAINER} \
      /usr/local/bin/bazel test ... \
        --copt="-Wall" \
        --copt="-Werror" \
        --define="absl=${absl}" \
        --keep_going \
        --show_timestamps \
        --test_output=errors
  done
done

# Test Clang
for std in ${STD}; do
  for absl in 0 1; do
    time docker run \
      --volume="${GTEST_ROOT}:/src:ro" \
      --workdir="/src" \
      --rm \
      --env="CC=/opt/llvm/clang/bin/clang" \
      --env="BAZEL_CXXOPTS=-std=${std}" \
      ${LINUX_LATEST_CONTAINER} \
      /usr/local/bin/bazel test ... \
        --copt="--gcc-toolchain=/usr/local" \
        --copt="-Wall" \
        --copt="-Werror" \
        --define="absl=${absl}" \
        --keep_going \
        --linkopt="--gcc-toolchain=/usr/local" \
        --show_timestamps \
        --test_output=errors
  done
done
