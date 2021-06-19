package io.openvidu.java.client;

public class RtmpLink {
    private SocialProvider socialProvider;
    private String rtmpLink;

    public RtmpLink() {
    }

    public RtmpLink(SocialProvider socialProvider, String rtmpLink) {
        this.socialProvider = socialProvider;
        this.rtmpLink = rtmpLink;
    }

    public SocialProvider getSocialProvider() {
        return socialProvider;
    }

    public void setSocialProvider(SocialProvider socialProvider) {
        this.socialProvider = socialProvider;
    }

    public String getRtmpLink() {
        return rtmpLink;
    }

    public void setRtmpLink(String rtmpLink) {
        this.rtmpLink = rtmpLink;
    }

    @Override
    public String toString() {
        return "RtmpLink{" +
                "socialProvider=" + socialProvider +
                ", rtmpLink='" + rtmpLink + '\'' +
                '}';
    }
}
