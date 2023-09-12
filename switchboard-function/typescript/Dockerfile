# syntax=docker/dockerfile:1.4
FROM switchboardlabs/sgx-function AS builder

WORKDIR /home/root/switchboard-function
COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json ./
COPY ./src/ ./src/
RUN npm run build

FROM switchboardlabs/sgx-function

# Copy the binary
WORKDIR /sgx
COPY --from=builder /home/root/switchboard-function/dist/ /sgx/nodejs/

# Get the measurement from the enclave
RUN rm -f /measurement.txt && \
    /get_measurement.sh --nodejs && \
    cat /measurement.txt

ENTRYPOINT ["bash", "/boot.sh", "--nodejs"]