<?php

namespace Phrost;

enum Channels: int
{
    case RENDERER = 0;
    case INPUT = 1;
    case PHYSICS = 2;
    case AUDIO = 3;
    case GUI = 4;
    case WINDOW = 5;
    case SCRIPT = 6;
}

/**
 * Manages packing events into multiple "channels".
 *
 * This class contains multiple CommandPacker instances, one for each channel.
 * When finalized, it produces a single binary blob structured as:
 *
 * 1. Channel Count (u32)
 * 2. Index Table   [Channel ID (u32), Channel Size (u32)] * N
 * 3. Data Blobs    [Channel 0 Data]...[Channel N Data]
 *
 * Each "Channel Data" blob is the complete output from a single CommandPacker
 * (i.e., it starts with its own internal event count).
 */
class ChannelPacker
{
    /**
     * Stores the individual packer for each channel.
     *
     * @var array<int, CommandPacker>
     */
    private array $channelPackers = [];

    /**
     * Adds an event to a specific channel.
     *
     * If the channel doesn't exist, a new CommandPacker is created for it.
     *
     * @param int    $channelId The channel to add this event to.
     * @param Events $type      The event type.
     * @param array  $data      The event data.
     */
    public function add(int $channelId, Events $type, array $data): void
    {
        if (!isset($this->channelPackers[$channelId])) {
            // Create a new packer for this channel.
            // We set chunkSize to 0 to disable the internal buffering
            // in CommandPacker, as ChannelPacker handles the final flush.
            $this->channelPackers[$channelId] = new CommandPacker(0);
        }

        $this->channelPackers[$channelId]->add($type, $data);
    }

    /**
     * Finalizes all channel packers and combines them into a single binary blob
     * prefixed with the channel index.
     *
     * @return string The complete binary blob.
     */
    public function finalize(): string
    {
        if (empty($this->channelPackers)) {
            return "";
        }

        // Sort by channel ID to ensure a consistent order
        ksort($this->channelPackers);

        $indexTable = "";
        $dataBlobs = "";
        $channelCount = count($this->channelPackers);

        foreach ($this->channelPackers as $channelId => $packer) {
            // Get the finalized blob for this channel (starts with its own event count)
            $channelBlob = $packer->finalize();
            $channelSize = strlen($channelBlob);

            // Add to the index table: [Channel ID (u32), Channel Size (u32)]
            $indexTable .= pack("VV", $channelId, $channelSize);

            // Add this channel's data to the main data blob
            $dataBlobs .= $channelBlob;
        }

        // 1. Pack the total number of channels
        $output = pack("V", $channelCount);
        // 2. Append the index table
        $output .= $indexTable;
        // 3. Append the concatenated data blobs
        $output .= $dataBlobs;

        // Clear the packers for reuse
        $this->channelPackers = [];

        return $output;
    }

    /**
     * Gets the total number of events buffered across all channels.
     */
    public function getTotalEventCount(): int
    {
        $total = 0;
        foreach ($this->channelPackers as $packer) {
            $total += $packer->getTotalEventCount();
        }
        return $total;
    }
}
