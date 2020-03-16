# Build Docker Image

To build BMS docker image, you will need to have the docker installed locally.
Then you can build the image with the following commands.

## Using Rake

If you have rake installed `gem install rake` then you can use the Rake tasks
to build and push the image.

```bash
rake build
# Validate your image was created with `docker image ls`
rake push # You will have to have authenticated with container-registry first. See below.
```

## Building Manually

```bash
# Build image
docker image build -t bms:<version> .
# Verify image
docker image ls bms
```

Now you will need to push it to container-registry. You will need to authenticate
before you can push the image. You will need to do these steps on the VA VPN
so that you can connect to Nexus.

```bash
# Login to container-registry (This only needs to be done once)
docker login https://container-registry.prod8.bip.va.gov
# Tag image
docker tag bms:<version> container-registry.prod8.bip.va.gov/bms:<version>
# Push image
docker push container-registry.prod8.bip.va.gov/bms:<version>
```

Now you should be able to verify the image is in the registry by visiting
https://nexus.prod8.bip.va.gov/.
