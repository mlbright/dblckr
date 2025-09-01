package main

import (
	"context"
	"fmt"
	"os"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
)

func main() {
	region := "us-east-1"
	if len(os.Args) > 1 {
		region = os.Args[1]
	}

	ctx := context.Background()
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to load config: %v\n", err)
		os.Exit(1)
	}

	ec2Client := ec2.NewFromConfig(cfg)

	// Get all availability zones
	azResp, err := ec2Client.DescribeAvailabilityZones(ctx, &ec2.DescribeAvailabilityZonesInput{})
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to describe availability zones: %v\n", err)
		os.Exit(1)
	}

	instanceTypes := []string{"t4g.nano", "t4g.micro"}
	validNanoZones := []string{}
	validMicroZones := []string{}

	for _, az := range azResp.AvailabilityZones {
		zoneName := aws.ToString(az.ZoneName)

		// Query offerings for both instance types in this zone
		offeringsResp, err := ec2Client.DescribeInstanceTypeOfferings(ctx, &ec2.DescribeInstanceTypeOfferingsInput{
			LocationType: "availability-zone",
			Filters: []ec2types.Filter{
				{
					Name:   aws.String("location"),
					Values: []string{zoneName},
				},
				{
					Name:   aws.String("instance-type"),
					Values: instanceTypes,
				},
			},
		})
		if err != nil {
			fmt.Fprintf(os.Stderr, "failed to describe instance type offerings for %s: %v\n", zoneName, err)
			continue
		}

		offered := map[string]bool{}
		for _, o := range offeringsResp.InstanceTypeOfferings {
			offered[string(o.InstanceType)] = true
		}

		if offered["t4g.nano"] && offered["t4g.micro"] {
			validNanoZones = append(validNanoZones, zoneName)
		}
		if offered["t4g.micro"] {
			validMicroZones = append(validMicroZones, zoneName)
		}
	}

	fmt.Println("Valid availability zones for t4g.nano:")
	for _, zone := range validNanoZones {
		fmt.Println(zone)
	}
	fmt.Println("Valid availability zones for t4g.micro:")
	for _, zone := range validMicroZones {
		fmt.Println(zone)
	}
}
